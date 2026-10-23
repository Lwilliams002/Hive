// Story level generator. Run from the repo root:  swift Tools/genlevels.swift
// Reads Tools/level-table.json and writes Hive/Resources/Levels/level_%03d.json for each entry.
// Level 1 is hand-kept and never generated (the table starts at 2; id 1 is refused).
//
// For level L with difficulty D:
//   waves = 5 + (L − 1)/5; the last wave is the boss wave.
//   non-boss wave i (1-based): budget B = D · (16 + 5L) · (0.6 + 0.1i)
//     shares: hornet min(0.35, 0.05L) (cost 3), beetle L ≥ 4 ? min(0.30, 0.04(L − 3)) : 0 (cost 4), rest wasps (cost 1)
//     counts = floor(share · B / cost), wasps at least 4; zero-count groups are omitted
//     every group spreads its count over a 24 s window from wave start: interval = max(0.15, 24 / count)
//     hpScale = max(1, D · (0.6 + 0.06(L − 1)))
//     delay: first wave 1.5, then 2.5 for L < 10 and 2.0 for L ≥ 10
//   boss wave (scales with L and D): the table's boss (count 1) at hpScale D · (0.4 + 0.06(L − 1)),
//     escort wasps round(D · (4 + L/3)) and, from L ≥ 6, hornets round(D · (L/5)), each over the same
//     24 s window (L/3 and L/5 are integer divisions; a group rounding to 0 is omitted); delay 3.0.
import Foundation

struct Entry { let id: Int; let name: String; let difficulty: Double; let boss: String }
struct Spawn { let type: String; let count: Int; let interval: Double }
struct Wave { let delay: Double; let isBoss: Bool; let hpScale: Double; let spawns: [Spawn] }

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

/// Rounded to 3 decimals; always at least one fractional digit ("2.0", "0.86", "1.07").
func num(_ v: Double) -> String {
    let r = (v * 1000).rounded() / 1000
    if r == r.rounded() { return String(format: "%.1f", r) }
    var s = String(format: "%.3f", r)
    while s.hasSuffix("0") { s.removeLast() }
    return s
}

func jsonString(_ s: String) -> String {
    let data = try! JSONSerialization.data(withJSONObject: [s], options: [])
    let arr = String(data: data, encoding: .utf8)!
    return String(arr.dropFirst().dropLast())
}

/// Spreads `count` spawns over a fixed 24 s window from wave start.
func window(_ count: Int) -> Double { max(0.15, 24.0 / Double(count)) }

func waves(for e: Entry) -> [Wave] {
    let L = e.id, D = e.difficulty, Ld = Double(e.id)
    let total = 5 + (L - 1) / 5
    let hornetShare = min(0.35, 0.05 * Ld)
    let beetleShare = L >= 4 ? min(0.30, 0.04 * Double(L - 3)) : 0
    let waspShare = 1 - hornetShare - beetleShare
    let normalHPScale = max(1, D * (0.6 + 0.06 * Double(L - 1)))
    var result: [Wave] = []
    for i in 1..<total {
        let budget = D * (16 + 5 * Ld) * (0.6 + 0.1 * Double(i))
        let wasps = max(4, Int(floor(waspShare * budget / 1)))
        let hornets = Int(floor(hornetShare * budget / 3))
        let beetles = Int(floor(beetleShare * budget / 4))
        var spawns = [Spawn(type: "wasp", count: wasps, interval: window(wasps))]
        if hornets > 0 { spawns.append(Spawn(type: "hornet", count: hornets, interval: window(hornets))) }
        if beetles > 0 { spawns.append(Spawn(type: "beetle", count: beetles, interval: window(beetles))) }
        let delay = i == 1 ? 1.5 : (L < 10 ? 2.5 : 2.0)
        result.append(Wave(delay: delay, isBoss: false, hpScale: normalHPScale, spawns: spawns))
    }
    var boss = [Spawn(type: e.boss, count: 1, interval: 0)]
    let escortWasps = Int((D * Double(4 + L / 3)).rounded())
    if escortWasps > 0 { boss.append(Spawn(type: "wasp", count: escortWasps, interval: window(escortWasps))) }
    if L >= 6 {
        let escortHornets = Int((D * Double(L / 5)).rounded())
        if escortHornets > 0 { boss.append(Spawn(type: "hornet", count: escortHornets, interval: window(escortHornets))) }
    }
    result.append(Wave(delay: 3.0, isBoss: true, hpScale: D * (0.4 + 0.06 * Double(L - 1)), spawns: boss))
    return result
}

func render(_ e: Entry, _ ws: [Wave]) -> String {
    var out = "{\n  \"id\": \(e.id),\n  \"name\": \(jsonString(e.name)),\n  \"waves\": [\n"
    let waveTexts = ws.map { w -> String in
        var s = "    {\n      \"delay\": \(num(w.delay)),\n"
        if w.isBoss { s += "      \"isBoss\": true,\n" }
        if abs(w.hpScale - 1) > 1e-9 { s += "      \"hpScale\": \(num(w.hpScale)),\n" }
        let spawnTexts = w.spawns.map {
            "        { \"type\": \(jsonString($0.type)), \"count\": \($0.count), \"interval\": \(num($0.interval)) }"
        }
        s += "      \"spawns\": [\n" + spawnTexts.joined(separator: ",\n") + "\n      ]\n    }"
        return s
    }
    out += waveTexts.joined(separator: ",\n") + "\n  ]\n}\n"
    return out
}

let tableURL = URL(fileURLWithPath: "Tools/level-table.json")
guard let tableData = try? Data(contentsOf: tableURL),
      let raw = try? JSONSerialization.jsonObject(with: tableData) as? [[String: Any]] else {
    fail("cannot read Tools/level-table.json (run from the repo root)")
}
let bosses: Set<String> = ["bear", "hornetQueen", "swarmMother"]
let outDir = URL(fileURLWithPath: "Hive/Resources/Levels")
for row in raw {
    guard let id = row["id"] as? Int, let name = row["name"] as? String,
          let difficulty = (row["difficulty"] as? NSNumber)?.doubleValue, let boss = row["boss"] as? String else {
        fail("bad table row: \(row)")
    }
    guard id >= 2 else { fail("level \(id): level 1 is hand-kept and must not be generated") }
    guard bosses.contains(boss) else { fail("level \(id): unknown boss \(boss)") }
    guard difficulty > 0 else { fail("level \(id): difficulty must be positive") }
    let e = Entry(id: id, name: name, difficulty: difficulty, boss: boss)
    let url = outDir.appendingPathComponent(String(format: "level_%03d.json", id))
    do { try render(e, waves(for: e)).write(to: url, atomically: true, encoding: .utf8) } catch { fail("\(url.path): \(error)") }
    print("wrote \(url.lastPathComponent)  D=\(num(difficulty))  \(name)")
}
