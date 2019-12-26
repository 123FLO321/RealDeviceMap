//
//  Stats.swift
//  RealDeviceMap
//
//  Created by versx on 12/22/19.
//

import Foundation
import PerfectLib
import PerfectMySQL

class Stats: JSONConvertibleObject {
    
    override func getJSONValues() -> [String : Any] {
        let pokemonStats = try? Stats.getPokemonStats()
        let pokemonIVStats = try? Stats.getPokemonIVStats()
        let raidStats = try? Stats.getRaidStats()
        let eggStats = try? Stats.getRaidEggStats()
        let gymStats = try? Stats.getGymStats()
        let pokestopStats = try? Stats.getPokestopStats()
        let questItemStats = try? Stats.getQuestItemStats()
        let questPokemonStats = try? Stats.getQuestPokemonStats()
        let invasionStats = try? Stats.getInvasionStats()
        let spawnpointStats = try? Stats.getSpawnpointStats()
        return [
            "pokemon_total": (pokemonStats?[0] ?? 0),
            "pokemon_active": (pokemonStats?[1] ?? 0),
            "pokemon_iv_total": (pokemonStats?[2] ?? 0),
            "pokemon_iv_active": (pokemonStats?[3] ?? 0),
            "pokemon_active_100iv": (pokemonStats?[4] ?? 0),
            "pokemon_active_90iv": (pokemonStats?[5] ?? 0),
            "pokemon_active_0iv": (pokemonStats?[6] ?? 0),
            "pokemon_total_shiny": (pokemonStats?[7] ?? 0),
            "pokemon_active_shiny": (pokemonStats?[8] ?? 0),
            "pokestops_total": (pokestopStats?[0] ?? 0),
            "pokestops_lures_normal": (pokestopStats?[1] ?? 0),
            "pokestops_lures_glacial": (pokestopStats?[2] ?? 0),
            "pokestops_lures_mossy": (pokestopStats?[3] ?? 0),
            "pokestops_lures_magnetic": (pokestopStats?[4] ?? 0),
            "pokestops_invasions": (pokestopStats?[5] ?? 0),
            "pokestops_quests": (pokestopStats?[6] ?? 0),
            "gyms_total": (gymStats?[0] ?? 0),
            "gyms_neutral": (gymStats?[1] ?? 0),
            "gyms_mystic": (gymStats?[2] ?? 0),
            "gyms_valor": (gymStats?[3] ?? 0),
            "gyms_instinct": (gymStats?[4] ?? 0),
            "gyms_raids": (gymStats?[5] ?? 0),
            "pokemon_stats": pokemonIVStats as Any,
            "raid_stats": raidStats as Any,
            "egg_stats": eggStats as Any,
            "quest_item_stats": questItemStats as Any,
            "quest_pokemon_stats": questPokemonStats as Any,
            "invasion_stats": invasionStats as Any,
            "spawnpoints_total": (spawnpointStats?[0] ?? 0),
            "spawnpoints_found": (spawnpointStats?[1] ?? 0),
            "spawnpoints_missing": (spawnpointStats?[2] ?? 0)
        ]
    }
    
    public static func getTopPokemonStats(mysql: MySQL?=nil, lifetime: Bool) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql: String
        if lifetime {
            sql = """
            SELECT x.date, x.pokemon_id, SUM(shiny.count) as shiny, SUM(iv.count) as count
            FROM pokemon_stats x
              LEFT JOIN pokemon_shiny_stats shiny
              ON x.date = shiny.date AND x.pokemon_id = shiny.pokemon_id
              LEFT JOIN pokemon_iv_stats iv
              ON x.date = iv.date AND x.pokemon_id = iv.pokemon_id
            GROUP BY pokemon_id
            ORDER BY count DESC
            LIMIT 10
            """
        } else {
            sql = """
            SELECT x.date, x.pokemon_id, shiny.count AS shiny, iv.count
            FROM pokemon_stats x
              LEFT JOIN pokemon_shiny_stats shiny
              ON x.date = shiny.date AND x.pokemon_id = shiny.pokemon_id
              LEFT JOIN pokemon_iv_stats iv
              ON x.date = iv.date AND x.pokemon_id = iv.pokemon_id
            WHERE x.date = FROM_UNIXTIME(UNIX_TIMESTAMP(), '%Y-%m-%d')
            ORDER BY count DESC
            LIMIT 10
            """
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let date = result[0] as! String
            let pokemonId = result[1] as! UInt16
            let shiny: Int
            let count: Int
            if lifetime {
                shiny = Int(result[2] as? String ?? "0") ?? 0
                count = Int(result[3] as? String ?? "0") ?? 0
            } else {
                shiny = Int(result[2] as? Int32 ?? 0)
                count = Int(result[3] as! Int32)
            }
            let name = Localizer.global.get(value: "poke_\(pokemonId)")
            
            stats.append([
                "date": date,
                "pokemon_id": pokemonId,
                "name": name,
                "shiny": shiny.withCommas(),
                "count": count.withCommas()
            ])
            
        }
        return stats
    }
    
    public static func getTopPokemonIVStats(mysql: MySQL?=nil, iv: Double?=100) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT pokemon_id, iv, COUNT(iv) as count
        FROM `pokemon`
        WHERE
          first_seen_timestamp > UNIX_TIMESTAMP(NOW() - INTERVAL 24 HOUR) AND
          iv = ?
        GROUP BY pokemon_id
        ORDER BY count DESC
        LIMIT 10
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        mysqlStmt.bindParam(iv)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let pokemonId = result[0] as! UInt16
            let iv = result[1] as! Float
            let count = result[2] as! Int64
            let name = Localizer.global.get(value: "poke_\(pokemonId)")
            
            stats.append([
                "pokemon_id": pokemonId,
                "iv": iv,
                "name": name,
                "count": count.withCommas()
            ])
            
        }
        return stats
    }
    
    public static func getAllPokemonStats(mysql: MySQL?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT date, SUM(count) as count
        FROM `pokemon_stats`
        GROUP BY date
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let date = result[0] as! String
            let count = Int(result[1] as? String ?? "0") ?? 0
            
            stats.append([
                "date": date,
                "count": count.withCommas()
            ])
            
        }
        return stats
    }
    
    public static func getAllRaidStats(mysql: MySQL?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT date, SUM(count) as count
        FROM `raid_stats`
        GROUP BY date
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let date = result[0] as! String
            let count = Int(result[1] as? String ?? "0") ?? 0
            
            stats.append([
                "date": date,
                "count": count.withCommas()
            ])
            
        }
        return stats
    }
    
    public static func getAllQuestStats(mysql: MySQL?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT date, SUM(count) as count
        FROM `quest_stats`
        GROUP BY date
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let date = result[0] as! String
            let count = Int(result[1] as? String ?? "0") ?? 0
            
            stats.append([
                "date": date,
                "count": count.withCommas()
            ])
            
        }
        return stats
    }
    
    public static func getPokemonIVStats(mysql: MySQL?=nil, date: String?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let when = date == nil ? "FROM_UNIXTIME(UNIX_TIMESTAMP(), '%Y-%m-%d')" : "?"
        let sql = """
        SELECT x.date, x.pokemon_id, shiny.count as shiny, iv.count
        FROM pokemon_stats x
          LEFT JOIN pokemon_shiny_stats shiny
          ON x.date = shiny.date AND x.pokemon_id = shiny.pokemon_id
          LEFT JOIN pokemon_iv_stats iv
          ON x.date = iv.date AND x.pokemon_id = iv.pokemon_id
        WHERE x.date = \(when)
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        if date != nil {
            mysqlStmt.bindParam(date)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let date = result[0] as! String
            let pokemonId = result[1] as! UInt16
            let shiny = result[2] as? Int32 ?? 0
            let count = result[3] as? Int32 ?? 0
            let name = Localizer.global.get(value: "poke_\(pokemonId)")
            
            stats.append([
                "date": date,
                "pokemon_id": pokemonId,
                "name": name,
                "shiny": shiny.withCommas(),
                "count": count.withCommas()
            ])
            
        }
        return stats
        
    }
    
    public static func getPokemonStats(mysql: MySQL?=nil) throws -> [Int64] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT
          COUNT(id) AS total,
          SUM(expire_timestamp >= UNIX_TIMESTAMP()) AS active,
          SUM(iv IS NOT NULL) AS iv_total,
          SUM(iv IS NOT NULL AND expire_timestamp >= UNIX_TIMESTAMP()) AS iv_active,
          SUM(iv = 100 AND expire_timestamp >= UNIX_TIMESTAMP()) AS active_100iv,
          SUM(iv >= 90 AND iv < 100 AND expire_timestamp >= UNIX_TIMESTAMP()) AS active_90iv,
          SUM(iv = 0 AND expire_timestamp >= UNIX_TIMESTAMP()) AS active_0iv,
          SUM(shiny = 1) AS total_shiny,
          SUM(shiny = 1 AND expire_timestamp >= UNIX_TIMESTAMP()) AS active_shiny
        FROM pokemon
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var stats = [Int64]()
        while let result = results.next() {
            
            let total = result[0] as! Int64
            let active = Int64(result[1] as! String) ?? 0
            let ivTotal = Int64(result[2] as! String) ?? 0
            let ivActive = Int64(result[3] as! String) ?? 0
            let active100iv = Int64(result[4] as! String) ?? 0
            let active90iv = Int64(result[5] as! String) ?? 0
            let active0iv = Int64(result[6] as! String) ?? 0
            let totalShiny = Int64(result[7] as! String) ?? 0
            let activeShiny = Int64(result[8] as! String) ?? 0
            
            stats.append(total)
            stats.append(active)
            stats.append(ivTotal)
            stats.append(ivActive)
            stats.append(active100iv)
            stats.append(active90iv)
            stats.append(active0iv)
            stats.append(totalShiny)
            stats.append(activeShiny)
            
        }
        return stats
        
    }
    
    public static func getRaidStats(mysql: MySQL?=nil, date: String?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let when = date == nil ? "FROM_UNIXTIME(UNIX_TIMESTAMP(), '%Y-%m-%d')" : "?"
        let sql = """
        SELECT date, pokemon_id, count, level
        FROM raid_stats
        WHERE date = \(when)
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        if date != nil {
            mysqlStmt.bindParam(date)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let date = result[0] as! String
            let pokemonId = result[1] as! UInt16
            let count = result[2] as! Int32
            let level = result[3] as! UInt16
            let name = Localizer.global.get(value: "poke_\(pokemonId)")
            
            stats.append([
                "date": date,
                "pokemon_id": pokemonId,
                "name": name,
                "level": level,
                "count": count.withCommas()
            ])
            
        }
        return stats
        
    }
    
    public static func getRaidEggStats(mysql: MySQL?=nil, date: String?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let when = date == nil ? "FROM_UNIXTIME(UNIX_TIMESTAMP(), '%Y-%m-%d')" : "?"
        let sql = """
        SELECT date, level, count
        FROM raid_stats
        WHERE date = \(when)
        GROUP BY level
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        if date != nil {
            mysqlStmt.bindParam(date)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let date = result[0] as! String
            let level = result[1] as! UInt16
            let count = result[2] as! Int32
            
            stats.append([
                "date": date,
                "level": level,
                "count": count.withCommas()
            ])
            
        }
        return stats
        
    }
    
    public static func getPokestopStats(mysql: MySQL?=nil) throws -> [Int64] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT
          COUNT(id) AS total,
          SUM(lure_expire_timestamp > UNIX_TIMESTAMP() AND lure_id=501) AS normal_lures,
          SUM(lure_expire_timestamp > UNIX_TIMESTAMP() AND lure_id=502) AS glacial_lures,
          SUM(lure_expire_timestamp > UNIX_TIMESTAMP() AND lure_id=503) AS mossy_lures,
          SUM(lure_expire_timestamp > UNIX_TIMESTAMP() AND lure_id=504) AS magnetic_lures,
          SUM(incident_expire_timestamp > UNIX_TIMESTAMP()) invasions,
          SUM(quest_reward_type IS NOT NULL) quests
        FROM pokestop
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Int64]()
        while let result = results.next() {
            
            let total = result[0] as! Int64
            let normalLures = Int64(result[1] as! String)!
            let glacialLures = Int64(result[2] as! String)!
            let mossyLures = Int64(result[3] as! String)!
            let magneticLures = Int64(result[4] as! String)!
            let invasions = Int64(result[5] as! String)!
            let quests = Int64(result[6] as! String)!
            
            stats.append(total)
            stats.append(normalLures)
            stats.append(glacialLures)
            stats.append(mossyLures)
            stats.append(magneticLures)
            stats.append(invasions)
            stats.append(quests)
            
        }
        return stats
        
    }
    
    public static func getQuestItemStats(mysql: MySQL?=nil, date: String?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let when = date == nil ? "FROM_UNIXTIME(UNIX_TIMESTAMP(), '%Y-%m-%d')" : "?"
        let sql = """
        SELECT date, reward_type, item_id, count
        FROM quest_stats
        WHERE date = \(when)
        GROUP BY item_id
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        if date != nil {
            mysqlStmt.bindParam(date)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let date = result[0] as! String
            let rewardType = result[1] as! UInt16
            let itemId = result[2] as! UInt16
            let count = result[3] as! Int32
            let name = itemId == 0
                ? Localizer.global.get(value: "quest_reward_\(rewardType)")
                : Localizer.global.get(value: "item_\(itemId)")
            
            stats.append([
                "date": date,
                "reward_type": rewardType,
                "item_id": itemId,
                "name": name,
                "count": count.withCommas()
            ])
            
        }
        return stats
        
    }

    public static func getQuestPokemonStats(mysql: MySQL?=nil, date: String?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let when = date == nil ? "FROM_UNIXTIME(UNIX_TIMESTAMP(), '%Y-%m-%d')" : "?"
        let sql = """
        SELECT date, reward_type, pokemon_id, count
        FROM quest_stats
        WHERE date = \(when)
        GROUP BY pokemon_id
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        if date != nil {
            mysqlStmt.bindParam(date)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let date = result[0] as! String
            let rewardType = result[1] as! UInt16
            let pokemonId = result[2] as! UInt16
            let count = result[3] as! Int32
            let name = Localizer.global.get(value: "poke_\(pokemonId)")
            
            stats.append([
                "date": date,
                "reward_type": rewardType,
                "pokemon_id": pokemonId,
                "name": name,
                "count": count.withCommas()
            ])
            
        }
        return stats
        
    }
    
    public static func getInvasionStats(mysql: MySQL?=nil) throws -> [Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT grunt_type, COUNT(*) AS total
        FROM pokestop
        WHERE incident_expire_timestamp >= UNIX_TIMESTAMP()
        GROUP BY grunt_type
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Any]()
        while let result = results.next() {
            
            let gruntType = result[0] as! UInt16
            let count = result[1] as! Int64
            let name = Localizer.global.get(value: "grunt_\(gruntType)")
            
            stats.append([
                "type": gruntType,
                "name": name,
                "count": count.withCommas()
            ])
            
        }
        return stats
        
    }
    
    public static func getSpawnpointStats(mysql: MySQL?=nil) throws -> [Int64] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT
          COUNT(id) AS total,
          SUM(despawn_sec IS NOT NULL) AS found,
          SUM(despawn_sec IS NULL) AS missing,
          SUM(despawn_sec <= 1800) AS min30,
          SUM(despawn_sec > 1800) AS min60
        FROM spawnpoint
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Int64]()
        while let result = results.next() {
            
            let total = result[0] as! Int64
            let found = Int64(result[1] as! String) ?? 0
            let missing = Int64(result[2] as! String) ?? 0
            let min30 = Int64(result[3] as! String) ?? 0
            let min60 = Int64(result[4] as! String) ?? 0
            
            stats.append(total)
            stats.append(found)
            stats.append(missing)
            stats.append(min30)
            stats.append(min60)
            
        }
        return stats
        
    }
    
    public static func getGymStats(mysql: MySQL?=nil) throws -> [Int64] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT
          COUNT(id) AS total,
          SUM(team_id=0) AS neutral,
          SUM(team_id=1) AS mystic,
          SUM(team_id=2) AS valor,
          SUM(team_id=3) AS instinct,
          SUM(raid_pokemon_id IS NOT NULL AND raid_end_timestamp > UNIX_TIMESTAMP()) AS raids
        FROM gym
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [Int64]()
        while let result = results.next() {
            
            let total = result[0] as! Int64
            let neutral = Int64(result[1] as! String) ?? 0
            let mystic = Int64(result[2] as! String) ?? 0
            let valor = Int64(result[3] as! String) ?? 0
            let instinct = Int64(result[4] as! String) ?? 0
            let raids = Int64(result[5] as! String) ?? 0
            
            stats.append(total)
            stats.append(neutral)
            stats.append(mystic)
            stats.append(valor)
            stats.append(instinct)
            stats.append(raids)
            
        }
        return stats
        
    }
    
    public static func getCommDayStats(mysql: MySQL?=nil, pokemonId: UInt16, start: String, end: String) throws -> [String: Any] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[STATS] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT
          COUNT(id) AS total,
          SUM(iv > 0) AS with_iv,
          SUM(iv IS NULL) AS without_iv,
          SUM(iv = 0) AS iv_0,
          SUM(iv >= 1 AND iv < 10) AS iv_1_9,
          SUM(iv >= 10 AND iv < 20) AS iv_10_19,
          SUM(iv >= 20 AND iv < 30) AS iv_20_29,
          SUM(iv >= 30 AND iv < 40) AS iv_30_39,
          SUM(iv >= 40 AND iv < 50) AS iv_40_49,
          SUM(iv >= 50 AND iv < 60) AS iv_50_59,
          SUM(iv >= 60 AND iv < 70) AS iv_60_69,
          SUM(iv >= 70 AND iv < 80) AS iv_70_79,
          SUM(iv >= 80 AND iv < 90) AS iv_80_89,
          SUM(iv >= 90 AND iv < 100) AS iv_90_99,
          SUM(iv = 100) AS iv_100,
          SUM(gender = 1) AS male,
          SUM(gender = 2) AS female,
          SUM(gender = 3) AS genderless,
          SUM(level >= 1 AND level <= 9) AS level_1_9,
          SUM(level >= 10 AND level <= 19) AS level_10_19,
          SUM(level >= 20 AND level <= 29) AS level_20_29,
          SUM(level >= 30 AND level <= 35) AS level_30_35
        FROM
          pokemon
        WHERE
          pokemon_id = ?
          AND first_seen_timestamp >= ?
          AND first_seen_timestamp <= ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        mysqlStmt.bindParam(pokemonId)
        mysqlStmt.bindParam(start)
        mysqlStmt.bindParam(end)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[STATS] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var stats = [String: Any]()
        while let result = results.next() {
            
            stats["total"] = result[0] as! Int64
            stats["with_iv"] = Int64(result[1] as! String) ?? 0
            stats["without_iv"] = Int64(result[2] as! String) ?? 0

            stats["iv_0"] = Int64(result[3] as! String) ?? 0
            stats["iv_1_9"] = Int64(result[4] as! String) ?? 0
            stats["iv_10_19"] = Int64(result[5] as! String) ?? 0
            stats["iv_20_29"] = Int64(result[6] as! String) ?? 0
            stats["iv_30_39"] = Int64(result[7] as! String) ?? 0
            stats["iv_40_49"] = Int64(result[8] as! String) ?? 0
            stats["iv_50_59"] = Int64(result[9] as! String) ?? 0
            stats["iv_60_69"] = Int64(result[10] as! String) ?? 0
            stats["iv_70_79"] = Int64(result[11] as! String) ?? 0
            stats["iv_80_89"] = Int64(result[12] as! String) ?? 0
            stats["iv_90_99"] = Int64(result[13] as! String) ?? 0
            stats["iv_100"] = Int64(result[14] as! String) ?? 0
            
            stats["male"] = Int64(result[15] as! String) ?? 0
            stats["female"] = Int64(result[16] as! String) ?? 0
            stats["genderless"] = Int64(result[17] as! String) ?? 0
            
            stats["level_1_9"] = Int64(result[18] as! String) ?? 0
            stats["level_10_19"] = Int64(result[19] as! String) ?? 0
            stats["level_20_29"] = Int64(result[20] as! String) ?? 0
            stats["level_30_35"] = Int64(result[21] as! String) ?? 0
            
        }
        
        return stats
        
    }
    
}
