//
//  NetworkManager.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 14/11/25.
//


import Foundation

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
}

class NetworkManager {
    
    // Singleton instance
    static let shared = NetworkManager()
    
    // INI IP ADDRESS MAC SAVIO DI WIFI SWIFTFUN
    private let baseURL = "http://10.62.32.7:5002/api"
    
    private init() {}
    
    func scorePronunciation(text: String, audioURL: URL) async throws -> ScoreResponse {
        guard let url = URL(string: "\(baseURL)/score_pronunciation") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Load audio data
        let audioData = try Data(contentsOf: audioURL)
        
        // Build body
        let body = buildMultipartBody(boundary: boundary, text: text, audioData: audioData)
        request.httpBody = body
        
        // Perform Request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            // Try to parse server error message
            if let errorJson = try? JSONDecoder().decode([String: String].self, from: data) {
                throw NetworkError.serverError(errorJson["error"] ?? "Unknown error")
            }
            throw NetworkError.serverError("Server returned error code")
        }
        
        // Decode Response
        do {
            let result = try JSONDecoder().decode(ScoreResponse.self, from: data)
            return result
        } catch {
            print("Decoding Error: \(error)")
            throw NetworkError.decodingError
        }
    }
    
    // Helper to build the multipart body
    private func buildMultipartBody(boundary: String, text: String, audioData: Data) -> Data {
        var body = Data()
        
        // 1. Text Field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"text\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(text)\r\n".data(using: .utf8)!)
        
        // 2. Audio File
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 3. Close Boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
}
