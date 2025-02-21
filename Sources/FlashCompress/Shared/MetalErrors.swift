import Foundation

/// Errors that can occur during Metal operations
public enum MetalError: LocalizedError {
    case deviceCreationFailed
    case libraryCreationFailed
    case functionCreationFailed
    case pipelineCreationFailed
    case commandCreationFailed
    case bufferCreationFailed
    case libraryNotLoaded
    
    public var errorDescription: String? {
        switch self {
        case .deviceCreationFailed:
            return "Failed to create Metal device"
        case .libraryCreationFailed:
            return "Failed to create Metal library"
        case .functionCreationFailed:
            return "Failed to create Metal function"
        case .pipelineCreationFailed:
            return "Failed to create compute pipeline"
        case .commandCreationFailed:
            return "Failed to create command buffer or encoder"
        case .bufferCreationFailed:
            return "Failed to create Metal buffer"
        case .libraryNotLoaded:
            return "Metal library not loaded"
        }
    }
}
