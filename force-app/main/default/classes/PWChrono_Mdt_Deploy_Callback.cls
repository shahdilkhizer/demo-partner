public inherited sharing class PWChrono_Mdt_Deploy_Callback implements Metadata.DeployCallback {
  public void handleResult(
    Metadata.DeployResult result,
    Metadata.DeployCallbackContext context
  ) {
    if (result.status != Metadata.DeployStatus.Succeeded) {
      // Handle deployment failure
      PWChrono_Logger.error(
        'Metadata deployment failed: ' +
        result.details.componentFailures[0].problem
      );
    }
  }
}