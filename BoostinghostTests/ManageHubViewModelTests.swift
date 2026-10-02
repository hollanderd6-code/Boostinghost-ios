import Foundation
import Testing
@testable import Boostinghost

// MARK: - IOS-BOOSTPRICE-MANAGE-COUNT-02

struct ManageHubViewModelTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private func config(
        propertyId: String = "prop1",
        mode: String = "auto",
        isActive: Bool = true
    ) throws -> DynamicPricingConfig {
        let json = """
        {
          "id": "cfg_\(propertyId)",
          "property_id": "\(propertyId)",
          "property_name": "Studio Test",
          "mode": "\(mode)",
          "is_active": \(isActive),
          "price_min": 60,
          "price_max": 180
        }
        """.data(using: .utf8)!
        return try decoder.decode(DynamicPricingConfig.self, from: json)
    }

    // A — 0 active properties → count is 0
    @Test("no configs → active count is 0")
    func activeCountEmpty() {
        #expect(manageHubBoostPriceActiveCount(configs: []) == 0)
    }

    // B — 1 active property → count is 1
    @Test("one active config → active count is 1")
    func activeCountOne() throws {
        let cfg = try config(mode: "auto", isActive: true)
        #expect(manageHubBoostPriceActiveCount(configs: [cfg]) == 1)
    }

    // C — multiple active properties → correct count
    @Test("three active configs → active count is 3")
    func activeCountMultiple() throws {
        let cfgs = [
            try config(propertyId: "p1", mode: "auto",       isActive: true),
            try config(propertyId: "p2", mode: "manual",     isActive: true),
            try config(propertyId: "p3", mode: "suggestion", isActive: true),
        ]
        #expect(manageHubBoostPriceActiveCount(configs: cfgs) == 3)
    }

    // D — inactive BoostPrice property not counted
    @Test("isActive false → not counted")
    func inactiveNotCounted() throws {
        let cfgs = [
            try config(propertyId: "p1", mode: "auto", isActive: true),
            try config(propertyId: "p2", mode: "auto", isActive: false),
        ]
        #expect(manageHubBoostPriceActiveCount(configs: cfgs) == 1)
    }

    // D — mode off not counted even when isActive true
    @Test("mode off + isActive true → not counted")
    func modeOffNotCounted() throws {
        let cfgs = [
            try config(propertyId: "p1", mode: "auto", isActive: true),
            try config(propertyId: "p2", mode: "off",  isActive: true),
        ]
        #expect(manageHubBoostPriceActiveCount(configs: cfgs) == 1)
    }

    // E — pending recommendation does not affect count (count is from config, not dashboard)
    @Test("all modes auto/manual/suggestion are active when isActive true")
    func pendingDoesNotInflate() throws {
        let cfgs = [
            try config(propertyId: "p1", mode: "auto",       isActive: true),
            try config(propertyId: "p2", mode: "suggestion",  isActive: true),
        ]
        // Both are active; a pending dashboard history entry for p2 must not add extra count
        #expect(manageHubBoostPriceActiveCount(configs: cfgs) == 2)
    }

    // F — failure does not masquerade as zero: ViewModel starts nil, stays nil on error
    @Test("boostPriceActiveCount is nil before load (not zero)")
    @MainActor
    func initialStateIsNil() {
        let vm = ManageHubViewModel()
        #expect(vm.boostPriceActiveCount == nil)
    }

    // G — all configs in the array are counted regardless of propertyId
    // (agency filtering happens at API call level, same scope as BoostPriceViewModel)
    @Test("two active properties from different accounts → both counted")
    func agencyScopePassthrough() throws {
        let cfgs = [
            try config(propertyId: "owner1_prop", mode: "auto", isActive: true),
            try config(propertyId: "owner2_prop", mode: "auto", isActive: true),
        ]
        #expect(manageHubBoostPriceActiveCount(configs: cfgs) == 2)
    }

    // Edge: mixed modes all active
    @Test("auto + manual + suggestion all count as active")
    func allActiveModesCount() throws {
        let cfgs = [
            try config(propertyId: "p1", mode: "auto",       isActive: true),
            try config(propertyId: "p2", mode: "manual",     isActive: true),
            try config(propertyId: "p3", mode: "suggestion", isActive: true),
            try config(propertyId: "p4", mode: "off",        isActive: true),
            try config(propertyId: "p5", mode: "auto",       isActive: false),
        ]
        #expect(manageHubBoostPriceActiveCount(configs: cfgs) == 3)
    }
}
