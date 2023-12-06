//
//  SalatTimeData.swift
//  SalatTimeBar
//
//  Created by Aamir Jawaid on 8/5/23.
//

import Foundation
import Alamofire
import BackgroundTasks

struct SalatTimesJson: Decodable {
    struct SalatTimeDay: Decodable {
        struct SalatTimeDate: Decodable {
            var readable: String
            var timestamp: String
            
            var date: Date? {
                if let timeIntervalSince1970 = Double(self.timestamp) {
                    return Date(timeIntervalSince1970: timeIntervalSince1970)
                }
                
                return nil
            }
        }
        var timings: [String: String]
        var date: SalatTimeDate
    }
    
    var data:[SalatTimeDay]
}

let jsonData = JSON.data(using: .utf8)

let isoFormatter = ISO8601DateFormatter()

enum NetworkError: String, Error {
    // Throw when an invalid password is entered
    case InvalidDate = "InvalidDate"
    
    case InvalidData = "InvalidData"
    
    case NotAsked = "NotAsked"
}

struct Parameters: Encodable {
    let address: String
    let month: Int
    let year: Int
    let iso8601: String
}

let address = "621 Ilwaco Pl NE, Renton, WA"

fileprivate typealias StoredSalatTimes = (startOfMonthDate: Date, times: [SalatTime])

class AthanTimings: ObservableObject {
    static let shared = AthanTimings()
    
    private let fetcher: AthanNetworkFetcher
    private var timer: Timer?
    @Published var currentSalatTimes = Result<CurrentSalatTimes, NetworkError>.failure(.NotAsked)
    
    init() {
        self.fetcher = AthanNetworkFetcher()
    }
    
    deinit {
        print("Invalidating timer");
        self.timer?.invalidate()
    }
    
    func fetch() async -> Void {
        let currentMonth = Date.now.startOfMonth
        let nextMonth = currentMonth.computeDate(byAdding: .month, value: 1).startOfMonth
        print("fetching for \(currentMonth.description) \(nextMonth.description)")
        do {
            let dataForCurrentDate = try await self.fetcher.fetchAthanTimesIfNecessary(for: currentMonth)
            let dataForNextMonthDate = try await self.fetcher.fetchAthanTimesIfNecessary(for: nextMonth)
            DispatchQueue.main.async {
                var salatTimes: [SalatTime] = []
                [dataForCurrentDate, dataForNextMonthDate].forEach { data in
                    switch data {
                    case .success(let json):
                        salatTimes += json.times
                    case .failure(let error):
                        self.currentSalatTimes = .failure(error)
                    }
                }
                
                let currentSalatTime = CurrentSalatTimes(salatTimes: salatTimes)
                self.currentSalatTimes = .success(currentSalatTime)
                self.computeCurrentSalatIndex()
                self.scheduleRefresh()
            }
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    private func computeCurrentSalatIndex() {
        switch (self.currentSalatTimes) {
        case .success(let salatTimes):
            var currentSalatTime = salatTimes
            currentSalatTime.computeCurrentSalatIndex()
            self.currentSalatTimes = .success(currentSalatTime)
        case .failure(let error):
            print("No exisiting salat time because of \(error.localizedDescription)")
        }
    }
    
    private func scheduleRefresh() {
        self.timer?.invalidate()
        guard let timer = self.getRefreshBackgroundTask() else {
            return
        }
        
        
        self.timer = timer
        RunLoop.current.add(timer, forMode: .common)
    }
    
    private func getRefreshBackgroundTask() -> Timer? {
        switch (self.currentSalatTimes) {
        case .success(let currentTimes):
            if let currentSalatTime = currentTimes.currentSalatTime {
                print("Scheduled task \(currentSalatTime.time.timeIntervalSinceNow) seconds from now")
                return Timer(fire: currentSalatTime.time, interval: 0, repeats: false, block: { [weak self] timer in
                    guard let self = self, timer.isValid else {
                        print("Returning early")
                        return
                    }
                    print("Running a block")
                    Task {
                        print("Running a task")
                        await self.fetch()
                    }
                })
            }
        case .failure(let error):
            print("Not scheduling a task because of \(error.localizedDescription)")
        }
        
        return nil
    }
}

fileprivate class AthanNetworkFetcher {
    private var cache: Dictionary<String, [SalatTime]>
    
    init() {
        self.cache = Dictionary()
    }
    
    func fetchAthanTimesIfNecessary(for date: Date) async throws -> Result<StoredSalatTimes, NetworkError> {
        let components = date.get(.year, .month)
        guard let year = components.year, let month = components.month else {
            return .failure(.InvalidDate)
        }
    
        let cacheKey = "\(year)|\(month)"
        
        if let existingResult = self.cache[cacheKey] {
            return .success((startOfMonthDate: date.startOfMonth, times: existingResult))
        }
        
        let networkResult = try await self.fetchAthanTime(for: Parameters(address: address, month: month, year: year, iso8601: "true"))
        
        switch networkResult {
        case .success(let json):
            let results = json.data.flatMap { salatTimeDay in
                return salatTimeDay.timings.compactMap { (key, value) -> SalatTime? in
                    if let salatType = SalatType(rawValue: key), let salatTime = isoFormatter.date(from: value) {
                        return SalatTime(type: salatType, time: salatTime)
                    }
                    
                    return nil
                }
            }.sorted { a, b in
                a.time.compare(b.time) == .orderedAscending
            }
            
            self.cache[cacheKey] = results
            return .success((startOfMonthDate: date.startOfMonth, times: results))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    private func fetchAthanTime(for parameters: Parameters) async throws -> Result<SalatTimesJson, NetworkError> {
        return try await withCheckedThrowingContinuation { continuation in
            AF.request("http://api.aladhan.com/v1/calendarByAddress", method: .get, parameters: parameters).responseDecodable(of:SalatTimesJson.self) { response in
                switch response.result {
                case .success(let salatTime):
                    continuation.resume(returning: .success(salatTime))
                case .failure:
                    continuation.resume(returning: .failure(.InvalidData))
                }
            }
        }
    }
}

