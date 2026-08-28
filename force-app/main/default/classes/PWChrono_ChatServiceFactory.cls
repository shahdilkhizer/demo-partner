/**
 * Factory that resolves chat provider implementation.
 */
public inherited sharing class PWChrono_ChatServiceFactory {
  // Configurable via Custom Metadata/Settings
  private static final String PROVIDER_TYPE = 'SALESFORCE'; // or 'GOOGLE_CHAT'

  /**
   * Returns configured chat provider implementation.
   * @return Active chat provider
   */
  public static PWChrono_IChatProvider getProvider() {
    // In a real scenario, query Custom Metadata here
    if (PROVIDER_TYPE == 'GOOGLE_CHAT') {
      // return new PWChrono_GoogleChatProvider();
      throw new PWChrono_ChatException(
        'Google Chat integration not yet configured.'
      );
    }

    return new PWChrono_SalesforceChatProvider();
  }
}