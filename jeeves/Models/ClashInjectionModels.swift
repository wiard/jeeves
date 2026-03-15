import Foundation

struct SystemReadinessEnvelope: Decodable, Sendable {
    let ok: Bool?
    let readiness: SystemReadinessSnapshot
}

struct Clashd27ComputerEnvelope: Decodable, Sendable {
    let ok: Bool?
    let computer: Clashd27ComputerSnapshot
    let controllerState: String?
    let controller_state: String?
    let aluActivity: String?
    let alu_activity: String?
    let cube: ComputerCubeTelemetrySnapshot?
    let residueMemory: ComputerResidueTelemetrySnapshot?
    let residue_memory: ComputerResidueTelemetrySnapshot?

    private enum CodingKeys: String, CodingKey {
        case ok
        case computer
        case controllerState
        case controller_state
        case aluActivity
        case alu_activity
        case cube
        case residueMemory
        case residue_memory
    }
}

struct SystemReadinessSnapshot: Decodable, Sendable {
    let state: String
    let commandInitiationReady: Bool
    let summary: String
    let targetOptions: [InjectionTargetOption]
    let bootstrap: BootstrapStatusSnapshot
}

struct BootstrapStatusSnapshot: Decodable, Sendable {
    let state: String
    let startedAtIso: String
    let updatedAtIso: String
    let availableAdapterTypes: [String]
    let checks: [BootstrapCheckSnapshot]

    private enum CodingKeys: String, CodingKey {
        case state
        case startedAtIso
        case updatedAtIso
        case availableAdapterTypes
        case available_adapter_types
        case checks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        state = (try? c.decodeIfPresent(String.self, forKey: .state)) ?? "booting"
        startedAtIso = (try? c.decodeIfPresent(String.self, forKey: .startedAtIso)) ?? ""
        updatedAtIso = (try? c.decodeIfPresent(String.self, forKey: .updatedAtIso)) ?? ""
        availableAdapterTypes = (try? c.decodeIfPresent([String].self, forKey: .availableAdapterTypes))
            ?? (try? c.decodeIfPresent([String].self, forKey: .available_adapter_types))
            ?? []
        checks = (try? c.decodeIfPresent([BootstrapCheckSnapshot].self, forKey: .checks)) ?? []
    }
}

struct BootstrapCheckSnapshot: Decodable, Hashable, Sendable {
    let id: String
    let label: String
    let status: String
    let detail: String
}

struct InjectionTargetOption: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let type: String
    let label: String
    let location: String
    let status: String
    let detail: String
    let mode: String?
}

struct InjectionTargetSnapshot: Decodable, Hashable, Sendable {
    let id: String
    let type: String
    let label: String
    let location: String
    let status: String?
    let detail: String?
}

struct ClashInjectionCommandRequest: Encodable, Sendable {
    let target: ClashInjectionTargetRequest
    let intent: String
    let notes: String?
}

struct ClashInjectionTargetRequest: Encodable, Sendable {
    let id: String
    let type: String
    let location: String
    let label: String
}

struct ClashInjectionCommandEnvelope: Decodable, Sendable {
    let ok: Bool?
    let session: InjectionSessionSnapshot
}

struct InjectionSessionsEnvelope: Decodable, Sendable {
    let ok: Bool?
    let sessions: [InjectionSessionSnapshot]
}

struct InjectionSessionEnvelope: Decodable, Sendable {
    let ok: Bool?
    let session: InjectionSessionSnapshot
}

struct InjectionCycleEnvelope: Decodable, Sendable {
    let ok: Bool?
    let sessionId: String
    let cycle: InjectionCycleSnapshot
}

struct InjectionFindingsEnvelope: Decodable, Sendable {
    let ok: Bool?
    let sessionId: String
    let findings: [InjectionFindingSnapshot]
    let consequences: [InjectionConsequenceSnapshot]
}

struct InjectionResidueEnvelope: Decodable, Sendable {
    let ok: Bool?
    let sessionId: String
    let residue: [InjectionResidueSnapshot]
}

struct InjectionSessionSnapshot: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let createdAt: String
    let startedAt: String?
    let completedAt: String?
    let status: String
    let failureReason: String?
    let command: InjectionCommandSnapshot
    let cycle: InjectionCycleSnapshot
    let computer: Clashd27ComputerSnapshot?
    let cube: CubeStateSnapshot?
    let residueMemory: [TuringResidueMemoryEntrySnapshot]
}

struct InjectionCommandSnapshot: Decodable, Hashable, Sendable {
    let id: String
    let issuedAt: String
    let issuedBy: String
    let intent: String
    let target: InjectionTargetSnapshot
    let notes: String?
}

struct Clashd27ComputerSnapshot: Decodable, Hashable, Sendable {
    let state: String
    let controllerState: String
    let aluActivity: String
    let activeSessionId: String?
    let mergedFindingCount: Int
    let lastSummary: String
    let lastUpdatedAt: String
    let cubeState: CubeStateSnapshot
    let residueMemory: ResidueMemorySnapshot
}

struct CubeStateSnapshot: Decodable, Hashable, Sendable {
    let size: Int
    let state: String
    let activeCellCount: Int
    let completedCellCount: Int
    let peakActiveCellCount: Int
    let pendingTaskCount: Int
    let summary: String
    let taskQueue: [ComputeTaskSnapshot]
    let results: [CubeResultSnapshot]
}

struct ResidueMemorySnapshot: Decodable, Hashable, Sendable {
    let state: String
    let entryCount: Int
    let lastWrittenAt: String?
    let lastConsequence: String?
    let summary: String
}

struct ComputerCubeTelemetrySnapshot: Decodable, Hashable, Sendable {
    let activeCells: Int?
    let active_cells: Int?
    let peakActiveCells: Int?
    let peak_active_cells: Int?
    let pendingTasks: Int?
    let pending_tasks: Int?
    let cubeTaskQueue: Int?
    let cube_task_queue: Int?
    let cubeResults: Int?
    let cube_results: Int?
}

struct ComputerResidueTelemetrySnapshot: Decodable, Hashable, Sendable {
    let entries: Int
    let state: String
}

struct ComputeTaskSnapshot: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let kind: String
    let perspective: String
    let description: String
}

struct CubeResultSnapshot: Decodable, Hashable, Sendable, Identifiable {
    let cellId: String
    let taskId: String
    let summary: String
    let findingIds: [String]

    var id: String { "\(cellId)|\(taskId)" }
}

struct TuringResidueMemoryEntrySnapshot: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let sessionId: String
    let consequenceId: String
    let consequence: String
    let meaning: String
    let memoryAddress: String
    let writtenAt: String
}

struct InjectionCycleSnapshot: Decodable, Hashable, Sendable {
    let current: String
    let events: [InjectionCycleEventSnapshot]
}

struct InjectionCycleEventSnapshot: Decodable, Hashable, Sendable, Identifiable {
    let state: String
    let at: String
    let detail: String

    var id: String { "\(state)|\(at)|\(detail)" }
}

struct InjectionFindingSnapshot: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let kind: String
    let title: String
    let summary: String
    let score: Double
    let severity: String
}

struct InjectionConsequenceSnapshot: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let summary: String
    let meaning: String
    let level: String
    let recordedAt: String
}

struct InjectionResidueSnapshot: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let consequenceId: String
    let consequence: String
    let meaning: String
    let emittedAt: String
}
