@isTest
private class PWChrono_NavigationController_Test {
  @isTest
  static void testGetNavigationMenuItems_BlankMenuName() {
    Test.startTest();
    List<PWChrono_NavigationController.NavigationItemWrapper> items = PWChrono_NavigationController.getNavigationMenuItems(
      '',
      'Live'
    );
    Test.stopTest();

    System.assertNotEquals(null, items, 'Method should always return a list.');
  }

  @isTest
  static void testGetNavigationMenuItems_CustomMenuName() {
    Test.startTest();
    List<PWChrono_NavigationController.NavigationItemWrapper> items = PWChrono_NavigationController.getNavigationMenuItems(
      'Default Navigation',
      'Live'
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      items,
      'Method should return a valid list.'
    );
  }
}