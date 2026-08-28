public inherited sharing class PWChrono_NavigationController {
  @AuraEnabled(cacheable=true)
  public static List<ConnectApi.NavigationMenuItem> getNavigationMenuItems(
    String menuName,
    String publishedState
  ) {
    if (String.isBlank(menuName)) {
      menuName = 'Default Navigation';
    }

    String networkId = Network.getNetworkId();
    if (networkId == null) {
      return new List<ConnectApi.NavigationMenuItem>();
    }

    try {
      // Find the menu ID by name using SOQL
      List<NavigationLinkSet> linkSets = [
        SELECT Id
        FROM NavigationLinkSet
        WHERE
          NetworkId = :networkId
          AND (MasterLabel = :menuName
          OR DeveloperName = :menuName)
        LIMIT 1
      ];

      if (!linkSets.isEmpty()) {
        String menuId = linkSets[0].Id;

        ConnectApi.NavigationMenuItemCollection items = ConnectApi.NavigationMenu.getCommunityNavigationMenu(
          networkId,
          menuId,
          null,
          ConnectApi.PublishStatus.Live,
          false,
          false,
          null
        );
        return items.menuItems;
      }
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching navigation items.', e);
    }

    return new List<ConnectApi.NavigationMenuItem>();
  }
}