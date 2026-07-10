import UniformTypeIdentifiers
import CoreTransferable

extension NodeKind: Transferable {
    nonisolated static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
