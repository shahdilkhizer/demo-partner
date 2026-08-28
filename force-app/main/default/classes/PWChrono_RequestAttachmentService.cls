/**
 * @description Shared attachment service for request-based modules.
 *              Stores files in Salesforce Files and links them to request records.
 */
public inherited sharing class PWChrono_RequestAttachmentService {
  private static final Integer MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024;
  private static final Set<String> ALLOWED_EXTENSIONS = new Set<String>{
    'csv',
    'doc',
    'docx',
    'jpeg',
    'jpg',
    'pdf',
    'png',
    'txt',
    'xls',
    'xlsx'
  };
  private static final Set<String> ALLOWED_CONTENT_TYPES = new Set<String>{
    'application/msword',
    'application/pdf',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg',
    'image/png',
    'text/csv',
    'text/plain'
  };

  @AuraEnabled
  public static FileDescriptorDTO uploadFile(
    Id recordId,
    String fileName,
    String base64Data
  ) {
    return uploadFile(recordId, fileName, base64Data, null);
  }

  public static FileDescriptorDTO uploadFile(
    Id recordId,
    String fileName,
    String base64Data,
    String contentType
  ) {
    if (recordId == null) {
      throw new AuraHandledException('Record Id is required for file upload.');
    }
    if (String.isBlank(fileName) || String.isBlank(base64Data)) {
      throw new AuraHandledException('File name and data are required.');
    }
    if (!ContentVersion.SObjectType.getDescribe().isCreateable()) {
      throw new AuraHandledException(
        'You do not have permission to upload files.'
      );
    }

    String safeFileName = sanitizeFileName(fileName);
    validateExtension(safeFileName);
    validateContentType(contentType);
    Blob fileBody = decodeFile(base64Data);
    if (fileBody.size() > MAX_FILE_SIZE_BYTES) {
      throw new AuraHandledException('File exceeds the 5 MB upload limit.');
    }

    ContentVersion version = new ContentVersion();
    version.Title = safeFileName;
    version.PathOnClient = '/' + safeFileName;
    version.VersionData = fileBody;
    version.FirstPublishLocationId = recordId;
    insert version;

    version = [
      SELECT
        Id,
        ContentDocumentId,
        ContentDocument.Title,
        ContentDocument.FileType,
        ContentDocument.ContentSize,
        ContentDocument.CreatedDate,
        ContentDocument.CreatedBy.Name
      FROM ContentVersion
      WHERE Id = :version.Id
      LIMIT 1
    ];

    return mapVersion(version);
  }

  @AuraEnabled(cacheable=true)
  public static List<FileDescriptorDTO> getFilesForRecord(Id recordId) {
    if (recordId == null) {
      return new List<FileDescriptorDTO>();
    }
    if (!ContentDocumentLink.SObjectType.getDescribe().isAccessible()) {
      throw new AuraHandledException(
        'You do not have permission to view files.'
      );
    }

    List<FileDescriptorDTO> files = new List<FileDescriptorDTO>();
    for (ContentDocumentLink link : [
      SELECT
        ContentDocumentId,
        ContentDocument.Title,
        ContentDocument.FileType,
        ContentDocument.ContentSize,
        ContentDocument.CreatedDate,
        ContentDocument.CreatedBy.Name,
        ContentDocument.LatestPublishedVersionId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :recordId
      ORDER BY ContentDocument.CreatedDate DESC
    ]) {
      FileDescriptorDTO dto = new FileDescriptorDTO();
      dto.id = link.ContentDocumentId;
      dto.contentDocumentId = link.ContentDocumentId;
      dto.contentVersionId = link.ContentDocument.LatestPublishedVersionId;
      dto.name = link.ContentDocument.Title;
      dto.fileType = link.ContentDocument.FileType;
      dto.contentSize = link.ContentDocument.ContentSize;
      dto.sizeLabel = formatFileSize(link.ContentDocument.ContentSize);
      dto.createdDate = link.ContentDocument.CreatedDate;
      dto.createdByName = link.ContentDocument.CreatedBy != null
        ? link.ContentDocument.CreatedBy.Name
        : null;
      dto.downloadUrl =
        '/sfc/servlet.shepherd/document/download/' + link.ContentDocumentId;
      files.add(dto);
    }

    return files;
  }

  private static FileDescriptorDTO mapVersion(ContentVersion version) {
    FileDescriptorDTO dto = new FileDescriptorDTO();
    dto.id = version.ContentDocumentId;
    dto.contentDocumentId = version.ContentDocumentId;
    dto.contentVersionId = version.Id;
    dto.name = version.ContentDocument != null
      ? version.ContentDocument.Title
      : version.Title;
    dto.fileType = version.ContentDocument != null
      ? version.ContentDocument.FileType
      : null;
    dto.contentSize = version.ContentDocument != null
      ? version.ContentDocument.ContentSize
      : null;
    dto.sizeLabel = formatFileSize(dto.contentSize);
    dto.createdDate = version.ContentDocument != null
      ? version.ContentDocument.CreatedDate
      : null;
    dto.createdByName = version.ContentDocument != null &&
      version.ContentDocument.CreatedBy != null
      ? version.ContentDocument.CreatedBy.Name
      : null;
    dto.downloadUrl =
      '/sfc/servlet.shepherd/document/download/' + version.ContentDocumentId;
    return dto;
  }

  private static String formatFileSize(Integer bytes) {
    if (bytes == null) {
      return null;
    }
    if (bytes >= 1024 * 1024) {
      Decimal megaBytes = Decimal.valueOf(bytes) / (1024 * 1024);
      return megaBytes.setScale(1) + ' MB';
    }
    if (bytes >= 1024) {
      Decimal kiloBytes = Decimal.valueOf(bytes) / 1024;
      return kiloBytes.setScale(1) + ' KB';
    }
    return String.valueOf(bytes) + ' B';
  }

  private static Blob decodeFile(String base64Data) {
    try {
      return EncodingUtil.base64Decode(base64Data);
    } catch (Exception e) {
      throw new AuraHandledException('File data is not valid.');
    }
  }

  private static String sanitizeFileName(String fileName) {
    String safeFileName = fileName.trim()
      .replaceAll('[\\\\/\\r\\n\\t]+', '_')
      .replaceAll('[^A-Za-z0-9._ -]', '_');
    while (safeFileName.contains('..')) {
      safeFileName = safeFileName.replaceAll('\\.\\.', '.');
    }
    if (safeFileName.length() > 120) {
      safeFileName = safeFileName.substring(0, 120);
    }
    if (String.isBlank(safeFileName)) {
      throw new AuraHandledException('File name is not valid.');
    }
    return safeFileName;
  }

  private static void validateExtension(String fileName) {
    Integer dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == fileName.length() - 1) {
      throw new AuraHandledException('File type is required.');
    }
    String extension = fileName.substring(dotIndex + 1).toLowerCase();
    if (!ALLOWED_EXTENSIONS.contains(extension)) {
      throw new AuraHandledException('File type is not allowed.');
    }
  }

  private static void validateContentType(String contentType) {
    if (String.isBlank(contentType)) {
      return;
    }
    String normalizedType = contentType.trim().toLowerCase();
    if (!ALLOWED_CONTENT_TYPES.contains(normalizedType)) {
      throw new AuraHandledException('File content type is not allowed.');
    }
  }

  public class FileDescriptorDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id contentDocumentId;
    @AuraEnabled
    public Id contentVersionId;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String fileType;
    @AuraEnabled
    public Integer contentSize;
    @AuraEnabled
    public String sizeLabel;
    @AuraEnabled
    public Datetime createdDate;
    @AuraEnabled
    public String createdByName;
    @AuraEnabled
    public String downloadUrl;
  }
}