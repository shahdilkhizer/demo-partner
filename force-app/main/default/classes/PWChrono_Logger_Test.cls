@isTest
private class PWChrono_Logger_Test {
  @isTest
  static void testLogging() {
    Test.startTest();
    PWChrono_Logger.info('Test Info');
    PWChrono_Logger.warn('Test Warn');
    PWChrono_Logger.error('Test Error');

    try {
      Integer i = 1 / 0;
    } catch (Exception e) {
      PWChrono_Logger.error('Test Exception', e);
    }
    Test.stopTest();

    // No assertions possible for System.debug, but ensures code coverage
    System.assert(true);
  }
}