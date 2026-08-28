/**
 * @description Utility class for centralized logging
 * @author PWChrono Team
 */
public inherited sharing class PWChrono_Logger {
  private static final Integer MAX_LOG_MESSAGE_LENGTH = 2000;

  private static Boolean isLoggingEnabled() {
    if (Test.isRunningTest()) {
      return true;
    }

    return FeatureManagement.checkPermission('PWChrono_Enable_Logs');
  }

  private static String normalizeMessage(String message) {
    String normalized = String.isBlank(message) ? 'N/A' : message.trim();
    if (normalized.length() > MAX_LOG_MESSAGE_LENGTH) {
      return normalized.substring(0, MAX_LOG_MESSAGE_LENGTH) + '...';
    }
    return normalized;
  }

  private static void write(
    LoggingLevel level,
    String category,
    String message
  ) {
    if (!isLoggingEnabled()) {
      return;
    }

    System.debug(
      level,
      '[PWChrono] ' + category + ': ' + normalizeMessage(message)
    );
  }

  public static void error(String message) {
    write(LoggingLevel.ERROR, 'ERROR', message);
  }

  public static void error(String message, Exception e) {
    String exceptionType = e == null ? 'UnknownException' : e.getTypeName();
    String exceptionMessage = e == null || String.isBlank(e.getMessage())
      ? 'No exception message.'
      : e.getMessage();
    write(
      LoggingLevel.ERROR,
      'ERROR',
      message + ' | ' + exceptionType + ' | ' + exceptionMessage
    );
  }

  public static void warn(String message) {
    write(LoggingLevel.WARN, 'WARN', message);
  }

  public static void info(String message) {
    write(LoggingLevel.INFO, 'INFO', message);
  }
}