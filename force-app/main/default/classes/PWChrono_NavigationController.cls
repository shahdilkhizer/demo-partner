public without sharing class PWChrono_NavigationController {
  public class NavigationItemWrapper {
    @AuraEnabled public String id { get; set; }
    @AuraEnabled public String label { get; set; }
    @AuraEnabled public String actionType { get; set; }
    @AuraEnabled public String actionValue { get; set; }
    @AuraEnabled public String target { get; set; }
    @AuraEnabled public String type { get; set; }
    @AuraEnabled public List<NavigationItemWrapper> subMenu { get; set; }

    public NavigationItemWrapper() {
      this.subMenu = new List<NavigationItemWrapper>();
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<NavigationItemWrapper> getNavigationMenuItems(
    String menuName,
    String publishedState
  ) {
    if (String.isBlank(menuName)) {
      menuName = 'Default Navigation';
    }

    String networkId = Network.getNetworkId();
    if (String.isBlank(networkId)) {
      List<Network> nets = [
        SELECT Id
        FROM Network
        WHERE
          Name = 'Pulse Work Chrono'
          OR UrlPathPrefix = 'PulseWorkChronovforcesite'
          OR UrlPathPrefix = 'PulseWorkChrono'
        LIMIT 1
      ];
      if (!nets.isEmpty()) {
        networkId = nets[0].Id;
      }
    }

    try {
      // Find the menu ID by name using SOQL (without sharing allows guest users)
      List<NavigationLinkSet> linkSets = new List<NavigationLinkSet>();
      if (String.isNotBlank(networkId)) {
        linkSets = [
          SELECT Id, DeveloperName, MasterLabel
          FROM NavigationLinkSet
          WHERE
            NetworkId = :networkId
            AND (MasterLabel = :menuName
            OR DeveloperName = :menuName
            OR DeveloperName LIKE 'Default_Navigation%')
          LIMIT 1
        ];
      }

      if (linkSets.isEmpty()) {
        linkSets = [
          SELECT Id, DeveloperName, MasterLabel
          FROM NavigationLinkSet
          WHERE
            MasterLabel = :menuName
            OR DeveloperName = :menuName
            OR DeveloperName LIKE 'Default_Navigation%'
          LIMIT 1
        ];
      }

      if (!linkSets.isEmpty()) {
        String menuId = linkSets[0].Id;

        // 1. Try ConnectApi first
        try {
          ConnectApi.PublishStatus pubStatus = (publishedState == 'Draft')
            ? ConnectApi.PublishStatus.Draft
            : ConnectApi.PublishStatus.Live;

          ConnectApi.NavigationMenuItemCollection items = ConnectApi.NavigationMenu.getCommunityNavigationMenu(
            networkId,
            menuId,
            null,
            pubStatus,
            false,
            false,
            null
          );

          if (
            items != null &&
            items.menuItems != null &&
            !items.menuItems.isEmpty()
          ) {
            return convertConnectApiItems(items.menuItems);
          }
        } catch (Exception ex) {
          // ConnectApi may throw ConnectApiException in unauthenticated Guest context
          PWChrono_Logger.warn('ConnectApi failed for menu; using SOQL fallback: ' + ex.getMessage());
        }

        // 2. Guaranteed SOQL Fallback (Works 100% for Guest Users & Experience Cloud)
        return getMenuItemsFromSoql(menuId, publishedState);
      }
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching navigation items.', e);
    }

    return new List<NavigationItemWrapper>();
  }

  private static List<NavigationItemWrapper> convertConnectApiItems(
    List<ConnectApi.NavigationMenuItem> connectItems
  ) {
    List<NavigationItemWrapper> result = new List<NavigationItemWrapper>();
    if (connectItems == null) {
      return result;
    }

    for (ConnectApi.NavigationMenuItem ci : connectItems) {
      NavigationItemWrapper w = new NavigationItemWrapper();
      w.label = ci.label;
      w.actionType = String.valueOf(ci.actionType);
      w.type = String.valueOf(ci.actionType);
      w.actionValue = ci.actionValue;
      w.target = ci.actionValue;
      w.id = ci.label;
      if (ci.subMenu != null && !ci.subMenu.isEmpty()) {
        w.subMenu = convertConnectApiItems(ci.subMenu);
      }
      result.add(w);
    }
    return result;
  }

  private static List<NavigationItemWrapper> getMenuItemsFromSoql(
    String menuId,
    String publishedState
  ) {
    String statusFilter = (publishedState == 'Draft') ? 'Draft' : 'Live';

    List<NavigationMenuItem> menuRecords = [
      SELECT Id, Label, Type, Target, ParentId, Position, Status
      FROM NavigationMenuItem
      WHERE
        NavigationLinkSetId = :menuId
        AND (Status = :statusFilter
        OR Status = 'Live')
      ORDER BY Position ASC
    ];

    Map<String, NavigationItemWrapper> itemMap = new Map<String, NavigationItemWrapper>();
    List<NavigationItemWrapper> rootItems = new List<NavigationItemWrapper>();

    for (NavigationMenuItem mi : menuRecords) {
      NavigationItemWrapper w = new NavigationItemWrapper();
      w.id = mi.Id;
      w.label = mi.Label;
      w.actionType = mi.Type;
      w.type = mi.Type;
      w.actionValue = mi.Target;
      w.target = mi.Target;
      itemMap.put(mi.Id, w);
    }

    for (NavigationMenuItem mi : menuRecords) {
      NavigationItemWrapper w = itemMap.get(mi.Id);
      if (String.isNotBlank(mi.ParentId) && itemMap.containsKey(mi.ParentId)) {
        itemMap.get(mi.ParentId).subMenu.add(w);
      } else {
        rootItems.add(w);
      }
    }

    return rootItems;
  }
}