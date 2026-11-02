import Foundation

struct AppEnvironment {
    let repository: CardRepository
    let imageStore: ImageStore
    let ocr: OCRService
    let detection: CardDetectionService
    let parser: FieldParser
    let clock: Clock
    let cameraPermission: CameraPermissionProviding
    let exportWriter: VCardFileWriter
    let launchOptions: LaunchOptions

    init(
        repository: CardRepository,
        imageStore: ImageStore,
        ocr: OCRService,
        detection: CardDetectionService,
        parser: FieldParser,
        clock: Clock = SystemClock(),
        cameraPermission: CameraPermissionProviding = CameraPermissionService(),
        exportWriter: VCardFileWriter = TemporaryVCardWriter(),
        launchOptions: LaunchOptions = LaunchOptions()
    ) {
        self.repository = repository
        self.imageStore = imageStore
        self.ocr = ocr
        self.detection = detection
        self.parser = parser
        self.clock = clock
        self.cameraPermission = cameraPermission
        self.exportWriter = exportWriter
        self.launchOptions = launchOptions
    }

    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment {
        let options = LaunchOptions.parse(arguments)
        if options.isUITest {
            let repository: CardRepository
            let imageStore: ImageStore
            if options.persistentStore {
                let baseDirectory = FileManager.default.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                ).first!.appendingPathComponent("CamCardUITest", isDirectory: true)
                let imagesDirectory = baseDirectory.appendingPathComponent("images", isDirectory: true)
                repository = FileCardRepository(directory: baseDirectory, imagesDirectory: imagesDirectory)
                imageStore = FileImageStore(directory: imagesDirectory)
            } else {
                repository = InMemoryCardRepository()
                imageStore = InMemoryImageStore()
            }
            return AppEnvironment(
                repository: repository,
                imageStore: imageStore,
                ocr: MockOCRService(fixture: options.ocrFixture),
                detection: MockCardDetectionService(),
                parser: BusinessCardFieldParser(),
                clock: SystemClock(),
                cameraPermission: StaticCameraPermissionService(
                    current: options.skipCamera ? .unavailable : .authorized
                ),
                exportWriter: options.forceExportFailure ? FailingVCardWriter() : TemporaryVCardWriter(),
                launchOptions: options
            )
        }
        let baseDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("CamCard", isDirectory: true)
        let imagesDirectory = baseDirectory.appendingPathComponent("images", isDirectory: true)
        return AppEnvironment(
            repository: FileCardRepository(directory: baseDirectory, imagesDirectory: imagesDirectory),
            imageStore: FileImageStore(directory: imagesDirectory),
            ocr: VisionOCRService(),
            detection: VisionCardDetectionService(),
            parser: BusinessCardFieldParser(),
            launchOptions: options
        )
    }
}
