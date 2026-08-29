import Foundation

// MARK: - Desktop API Client for iOS
public final class DesktopApiClient: ObservableObject {
    
    @Published public var baseUrl: String = "http://192.168.42.129:8080"
    @Published public var isConnected: Bool = false
    
    private let session: URLSession
    
    public init(baseUrl: String = "http://192.168.42.129:8080") {
        self.baseUrl = baseUrl
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0
        config.timeoutIntervalForResource = 15.0
        self.session = URLSession(configuration: config)
    }
    
    public func updateBaseUrl(_ url: String) {
        var cleanUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanUrl.starts(with: "http://") && !cleanUrl.starts(with: "https://") {
            cleanUrl = "http://\(cleanUrl)"
        }
        if cleanUrl.hasSuffix("/") {
            cleanUrl = String(cleanUrl.dropLast())
        }
        self.baseUrl = cleanUrl
        checkHealth()
    }
    
    public func checkHealth(completion: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: "\(baseUrl)/api/health") else {
            DispatchQueue.main.async { self.isConnected = false }
            completion?(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        session.dataTask(with: request) { [weak self] data, response, error in
            let healthy = (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async {
                self?.isConnected = healthy
                completion?(healthy)
            }
        }.resume()
    }
    
    public func sendCardData(payload: CardDataPayload, completion: @escaping (Result<DesktopApiResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/api/national-id/read") else {
            completion(.failure(NSError(domain: "NIReader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Server URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(payload)
            request.httpBody = jsonData
        } catch {
            completion(.failure(error))
            return
        }
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NIReader", code: -2, userInfo: [NSLocalizedDescriptionKey: "Empty server response"])))
                }
                return
            }
            
            do {
                let apiResponse = try JSONDecoder().decode(DesktopApiResponse.self, data: data)
                DispatchQueue.main.async { completion(.success(apiResponse)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
}
