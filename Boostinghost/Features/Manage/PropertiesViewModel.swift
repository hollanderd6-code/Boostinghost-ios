import Foundation
import Observation

@Observable
@MainActor
final class PropertiesViewModel {
    enum LoadState { case loading, loaded, failed }

    var loadState: LoadState = .loading
    var properties: [Property] = []
    var groups: [PropertyGroup] = []
    var diffusionByProperty: [String: DiffusionProperty] = [:]
    var selectedGroupId: String? = nil  // nil = Tous

    // MARK: - Derived

    var filteredProperties: [Property] {
        guard let gid = selectedGroupId else { return properties }
        if gid == "__ungrouped__" {
            let grouped = Set(groups.flatMap { $0.propertyIds })
            return properties.filter { !grouped.contains($0.id) }
        }
        guard let group = groups.first(where: { $0.id == gid }) else { return properties }
        let ids = Set(group.propertyIds)
        return properties.filter { ids.contains($0.id) }
    }

    // Properties with a diffusion problem: !vendable (terracotta) or vendable && !diffuse (or).
    var problemProperties: [Property] {
        filteredProperties.filter { p in
            guard let d = diffusionByProperty[p.id] else { return false }
            return !d.vendable || !d.diffuse
        }
    }

    // Properties without a known problem — shown in the normal list card.
    var normalProperties: [Property] {
        filteredProperties.filter { p in
            guard let d = diffusionByProperty[p.id] else { return true }
            return d.vendable && d.diffuse
        }
    }

    func groupName(for property: Property) -> String? {
        groups.first(where: { $0.propertyIds.contains(property.id) })?.name
    }

    func count(for groupId: String) -> Int {
        if groupId == "__ungrouped__" { return ungroupedCount() }
        guard let group = groups.first(where: { $0.id == groupId }) else { return 0 }
        let ids = Set(group.propertyIds)
        return properties.filter { ids.contains($0.id) }.count
    }

    func ungroupedCount() -> Int {
        let grouped = Set(groups.flatMap { $0.propertyIds })
        return properties.filter { !grouped.contains($0.id) }.count
    }

    func updateProperty(_ updated: Property) {
        if let idx = properties.firstIndex(where: { $0.id == updated.id }) {
            properties[idx] = updated
        }
    }

    func removeProperty(id: String) {
        properties.removeAll { $0.id == id }
    }

    // MARK: - Load

    func load() async {
        loadState = .loading

        async let propsTask: PropertiesResponse = APIClient.shared.get(Endpoint.properties, agencyAll: true)
        async let groupsTask: PropertyGroupsResponse = APIClient.shared.get(Endpoint.propertyGroups, agencyAll: true)
        async let diffTask: DiffusionResponse = APIClient.shared.get(Endpoint.propertiesDiffusion, agencyAll: true)

        do {
            properties = ((try await propsTask).properties ?? [])
                .filter { !$0.id.isEmpty }
                .sorted { ($0.internalName ?? $0.name) < ($1.internalName ?? $1.name) }
        } catch {
            loadState = .failed
            return
        }

        groups = ((try? await groupsTask)?.groups ?? [])
            .sorted { $0.name < $1.name }

        if let diff = try? await diffTask {
            var dict: [String: DiffusionProperty] = [:]
            for logement in diff.logements { dict[logement.id] = logement }
            diffusionByProperty = dict
        }

        #if DEBUG
        print("[PropertiesViewModel] --- diffusion debug ---")
        for p in properties {
            let chx  = p.channexEnabled == true ? "channex=YES" : "channex=NO "
            let ical = (p.icalUrls?.isEmpty == false || (p.icalUrlsRaw ?? "[]") != "[]")
                       ? "ical=YES" : "ical=NO "
            if let d = diffusionByProperty[p.id] {
                print("[PropertiesViewModel]  \(chx) \(ical) vendable=\(d.vendable ? "Y" : "N") diffuse=\(d.diffuse ? "Y" : "N") aRegler=\(d.aRegler)  \(p.internalName ?? p.name)")
            } else {
                print("[PropertiesViewModel]  \(chx) \(ical) ABSENT de diffusionByProperty  \(p.internalName ?? p.name)")
            }
        }
        print("[PropertiesViewModel] ---------------------")
        #endif

        loadState = .loaded
    }
}
