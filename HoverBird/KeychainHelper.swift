//
//  KeychainHelper.swift
//  HoverSharky
//
//  Secure storage for in-app purchase state
//

import Foundation
import Security

@MainActor
class KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() {}
    
    // MARK: - Save Bool
    
    func save(_ value: Bool, forKey key: String) {
        let data = Data([value ? 1 : 0])
        save(data: data, forKey: key)
    }
    
    // MARK: - Load Bool
    
    func loadBool(forKey key: String) -> Bool? {
        guard let data = loadData(forKey: key), let firstByte = data.first else {
            return nil
        }
        return firstByte == 1
    }
    
    // MARK: - Save Data
    
    private func save(data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("KeychainHelper: Failed to save data for key '\(key)', status: \(status)")
        }
    }
    
    // MARK: - Load Data
    
    private func loadData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }
    
    // MARK: - Delete
    
    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
