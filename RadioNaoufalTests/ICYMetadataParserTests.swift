import XCTest
@testable import RadioNaoufal

final class ICYMetadataParserTests: XCTestCase {

    func testParseSimpleArtistTitle() {
        let parsed = ICYMetadataParser.parseStreamTitle("Coldplay - Yellow")
        XCTAssertEqual(parsed.artist, "Coldplay")
        XCTAssertEqual(parsed.title, "Yellow")
    }

    func testParseTitleWithEmDash() {
        let parsed = ICYMetadataParser.parseStreamTitle("Tiesto — Adagio for Strings")
        XCTAssertEqual(parsed.artist, "Tiesto")
        XCTAssertEqual(parsed.title, "Adagio for Strings")
    }

    func testParseTitleOnly() {
        let parsed = ICYMetadataParser.parseStreamTitle("Nieuws met Sander")
        XCTAssertEqual(parsed.title, "Nieuws met Sander")
        XCTAssertNil(parsed.artist)
    }

    func testParseEmpty() {
        let parsed = ICYMetadataParser.parseStreamTitle("   ")
        XCTAssertNil(parsed.title)
        XCTAssertNil(parsed.artist)
    }
}

final class StationModelTests: XCTestCase {

    func testGenreLocalizedLabel() {
        XCTAssertFalse(Station.Genre.classical.localizedLabel.isEmpty)
        XCTAssertFalse(Station.Genre.news.localizedLabel.isEmpty)
    }

    func testStationEquatableByID() {
        let a = Station(
            id: "test",
            name: "Test 1",
            streamURL: URL(string: "https://example.com/a")!,
            genre: .hits
        )
        let b = Station(
            id: "test",
            name: "Test 2",
            streamURL: URL(string: "https://example.com/b")!,
            genre: .news
        )
        XCTAssertEqual(a.id, b.id)
    }
}

@MainActor
final class StationsRepositoryTests: XCTestCase {

    func testLoadsCuratedFromBundle() throws {
        let repo = StationsRepository()
        XCTAssertGreaterThan(repo.curated.count, 10)
        XCTAssertTrue(repo.curated.contains(where: { $0.id == "npo-radio2" }))
    }

    func testNextAndPreviousStation() throws {
        let repo = StationsRepository()
        guard let first = repo.curated.first else {
            XCTFail("No curated stations loaded")
            return
        }
        XCTAssertNotNil(repo.nextStation(after: first.id))
        XCTAssertNotNil(repo.previousStation(before: first.id))
    }
}

@MainActor
final class DataStoreTests: XCTestCase {

    private func temporaryStore() -> DataStore {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DataStoreTest-\(UUID())")
        return DataStore(baseDirectory: tempDir)
    }

    func testFavoritePersistence() throws {
        let store = temporaryStore()
        XCTAssertNil(store.favorite(at: 1))
        store.setFavorite(.init(slotIndex: 1, stationID: "npo-radio1", stationName: "NPO Radio 1"))
        XCTAssertEqual(store.favorite(at: 1)?.stationID, "npo-radio1")
        store.clearFavorite(slot: 1)
        XCTAssertNil(store.favorite(at: 1))
    }

    func testRecentDedup() throws {
        let store = temporaryStore()
        store.appendRecent(.init(stationID: "a", stationName: "A"))
        store.appendRecent(.init(stationID: "b", stationName: "B"))
        store.appendRecent(.init(stationID: "a", stationName: "A"))
        XCTAssertEqual(store.recents.count, 2)
        XCTAssertEqual(store.recents.first?.stationID, "a")
    }
}
