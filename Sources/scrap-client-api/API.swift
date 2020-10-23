import Foundation
import Combine
import scrap_data_models

//MARK: Typealiases
public typealias StatusCode = Int
public typealias ErrorTransform = (Data, StatusCode) -> API.Error
public typealias ResponseTransform<T> = (Data, JSONDecoder) throws -> T

//MARK: Request signatures
public typealias RegisterRequest = (UserRegistrationCandidate) -> AnyPublisher<String, API.Error>
public typealias LoginRequest = (UserLoginCandidate) -> AnyPublisher<Token, API.Error>
public typealias TestRequest = () -> AnyPublisher<String, API.Error>

public struct API {
    private static let client = Client()
    
    public init() {}
    
    public init(
        login: @escaping LoginRequest,
        register: @escaping RegisterRequest
    ) {
        
    }
    //TODO: Perhaps API should also have a SideEffects struct
    public var hasToken = CurrentValueSubject<Bool, Never>(TokenHandler().tokenValue() != nil)
    
    //MARK: Endpoints
    public func login(loginCandidate: UserLoginCandidate) -> AnyPublisher<Token, API.Error> {
        let request = URLRequest
            .post(.login)
            .basicAuthorized(forUser: loginCandidate)
        
        let errorTransform: ErrorTransform = { data, statusCode in
            return .server(message: "Dang!")
        }
        
        return API.client.run(request, errorTransform: errorTransform)
            .tryMap(saveTokenOrThrow)
            .mapError(silentErrorUnlessSpecified)
            .eraseToAnyPublisher()
    }
    
    public func register(registrationCandidate: UserRegistrationCandidate) -> AnyPublisher<String, API.Error> {
        
        let request = URLRequest
            .post(.register)
            .with(data: try? JSONEncoder().encode(registrationCandidate))
        
        //TODO: Perhaps use callAsFunction to be able to have static vars
        let errorTransform: ErrorTransform = { data, statusCode in
            guard
                [400, 409].map({ $0 == statusCode }).contains(true),
                let serverError = try? JSONDecoder().decode(ServerError.self, from: data)
            else {
                return .server(message: "Some generic error title")
            }
            
            return .server(message: serverError.reason)
        }
        
        return API.client.run(request, errorTransform: errorTransform)
            .tryMap(saveTokenOrThrow)
            .mapError(silentErrorUnlessSpecified)
            .flatMap { _ in
                return test()
            }
            .eraseToAnyPublisher()
    }
    
    public func test(tokenHandler: TokenHandler = TokenHandler(), mock: TestRequest? = nil) -> AnyPublisher<String, API.Error> {
        
        if let mock = mock {
            return mock()
        }
        
        guard
            let token = tokenHandler.tokenValue(),
            let request = URLRequest.get(.test).tokenAuthorized(token: token)
        else {
            return Fail<String, API.Error>(error: .missingToken)
                .eraseToAnyPublisher()
        }
        
        let responseTransform: ResponseTransform<String> = { data, _ in
            guard let value = String(data: data, encoding: .utf8) else {
                throw API.Error.silent
            }
            
            return value
        }
        
        return API.client.run(request, responseTransform: responseTransform)
            .map(\.value)
            .eraseToAnyPublisher()
    }
    
    public func clearToken() {
        //TODO: Verify the result of this action
        TokenHandler().clearToken()
        self.hasToken.send(TokenHandler().tokenValue() != nil)
    }
    
    fileprivate func saveTokenOrThrow(_ response: (Client.Response<Token>)) throws -> Token {
        guard
            case .success(_) = TokenHandler().saveToken(response.value)
        else {
            throw API.Error.couldNotStoreToken
        }
        self.hasToken.send(TokenHandler().tokenValue() != nil)
        
        return response.value
    }
}

public extension API {
    enum Error: Swift.Error {
        case couldNotStoreToken
        case missingToken
        case noNetwork
        case parse
        case server(message: String)
        case serverUnreachable
        case silent
        case unspecifiedURLError
    }
}

public struct ServerError: Decodable {
    let reason: String
}

public extension API {
    static var mock: API {
        API(
            login: { _ in Just(Token(value: "")).setFailureType(to: Error.self).eraseToAnyPublisher() },
            register: { _ in Just("").setFailureType(to: Error.self).eraseToAnyPublisher() }
        )
    }
}

//MARK: Fileprivate
extension URLRequest {
    static func post(_ endpoint: PostEndpoint) -> URLRequest {
        let base = "http://localhost:8080"
        let urlString: String
        
        switch endpoint {
        case .register:
            urlString = "\(base)/register"
        case .login:
            urlString = "\(base)/login"
        }
        
        let url = URL(string: urlString)
        var request = URLRequest(url: url!).withDefaultHeaders
        request.httpMethod = "POST"
        
        return request
    }
    
    static func get(_ endpoint: GetEndpoint) -> URLRequest {
        let base = "http://localhost:8080"
        let urlString: String
        
        switch endpoint {
        case .test:
            urlString = "\(base)/me"
        }
        
        let url = URL(string: urlString)
        var request = URLRequest(url: url!)
        request.httpMethod = "GET"
        
        return request
    }
}

enum PostEndpoint {
    case login
    case register
}

enum GetEndpoint {
    case test
}

extension URLRequest {
    func tokenAuthorized(token: Token) -> URLRequest? {
        var mutableSelf = self
        
        var headers = mutableSelf.allHTTPHeaderFields ?? [:]
        headers["Authorization"] = "Bearer \(token)"
        mutableSelf.allHTTPHeaderFields = headers
        
        return mutableSelf
    }
    
    func basicAuthorized(forUser user: UserLoginCandidate) -> URLRequest {
        var mutableSelf = self
        
        var headers = mutableSelf.allHTTPHeaderFields ?? [:]
        headers["Authorization"] = "Basic \(user.basicAuthorizationFormatted)"
        mutableSelf.allHTTPHeaderFields = headers
        
        return mutableSelf
    }
    
    var withDefaultHeaders: URLRequest {
        var mutableSelf = self
        
        var headers = mutableSelf.allHTTPHeaderFields ?? [:]
        headers["Content-Type"] = "application/json"
        mutableSelf.allHTTPHeaderFields = headers
        
        return mutableSelf
    }
    
    func with(data: Data?) -> URLRequest {
        var mutableSelf = self
        mutableSelf.httpBody = data
        
        return mutableSelf
    }
}

//MARK: Client
fileprivate struct Client {
    struct Response<T> {
        let value: T
        let response: URLResponse
    }
    
    func run<T: Decodable>(
        _ request: URLRequest,
        errorTransform: @escaping ErrorTransform = { _, _ in .silent },
        responseTransform: @escaping ResponseTransform<T> = { data, decoder in try decoder.decode(T.self, from: data) },
        decoder: JSONDecoder = JSONDecoder()
    ) -> AnyPublisher<Response<T>, API.Error> {
            return URLSession.shared
                .dataTaskPublisher(for: request)
                .mapError (standardURLErrorHandler )
                .tryMap { result -> Response<T> in
                    
                    guard let httpURLResponse = result.response as? HTTPURLResponse else {
                        //TODO: Is this correct?
                        throw API.Error.silent
                    }

                    guard (200...299) ~= httpURLResponse.statusCode else {
                        throw errorTransform(result.data, httpURLResponse.statusCode)
                    }
                    
                    //TODO: Parse errors should be handled
                    let value = try responseTransform(result.data, decoder)
                    
                    return Response(value: value, response: result.response)
                }
                .mapError(silentErrorUnlessSpecified)
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
}

fileprivate func silentErrorUnlessSpecified(_ error: Swift.Error) -> API.Error {
    guard let error = error as? API.Error else {
        return .silent
    }
    
    return error
}

fileprivate func standardURLErrorHandler(_ error: URLError) -> API.Error {
    if error.errorCode == NSURLErrorNotConnectedToInternet {
        return .noNetwork
    } else if error.errorCode == NSURLErrorCannotConnectToHost {
        return .serverUnreachable
    }
    
    return .unspecifiedURLError
}

//TODO: Move to Scrap data models

public struct UserLoginCandidate {
    public let email: String
    public let password: String
    
    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
    
    var basicAuthorizationFormatted: String {
        Data("\(email):\(password)".utf8).base64EncodedString()
    }
}

//TODO: Should this be a shared data model?
public struct Token: Codable, Equatable, CustomStringConvertible {
    public let value: String
    public var description: String { value }
    
    public init(value: String) {
        self.value = value
    }
}
