/** Factory that resolves the active chat provider. */
public inherited sharing class PWChrono_ChatServiceFactory {
  private static final String PROVIDER_TYPE = 'SALESFORCE';

  public static PWChrono_IChatProvider getProvider() {
    if (PROVIDER_TYPE == 'GOOGLE_CHAT') {
      throw new PWChrono_ChatException(
        'Google Chat integration not yet configured.'
      );
    }
    return new PWChrono_SalesforceChatProvider();
  }
}