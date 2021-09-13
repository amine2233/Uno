//
//  Uno
//
//  Created by Gaetano Matonti on 06/09/21.
//

import Foundation

/// An object that parses and validates `otpauth` URIs.
struct URIParser {
  /// The keys representing the names of `URLQueryItem`s in the URI.
  enum ItemKey: String {
    /// The algorithm item key.
    case algorithm
    
    /// The counter item key.
    case counter

    /// The digits item key.
    case digits

    /// The period item key.
    case period

    /// The secret item key.
    case secret
  }
  
  // MARK: - Constants
  
  /// The scheme of the `otpauth` URI.
  private static let scheme = "otpauth"
  
  // MARK: - Stored Properties
  
  /// The algorithm used by the service to generate OTPs.
  let algorithm: OneTimePassword.Algorithm
  
  /// The number of digits of the OTP.
  let codeLength: OneTimePassword.Length
  
  /// The kind of OTP generated by the service.
  let kind: OneTimePassword.Kind

  /// The secret used to authenticate the user with the service.
  let secret: OneTimePassword.Secret
  
  // MARK: - Init
  
  /// Creates an instance of `URIParser` from a URI `String`.
  /// - Parameter uri: The `String` of the `otpauth` URI.
  init(uri: String) throws {
    guard let components = URLComponents(string: uri) else {
      throw Error.invalidURI
    }
    
    guard let scheme = components.scheme else {
      throw Error.missingScheme
    }
    
    guard URIParser.isValidScheme(scheme) else {
      throw Error.invalidScheme
    }
    
    guard let otpType = components.host else {
      throw Error.missingOTPType
    }
        
    guard let queryItems = components.queryItems else {
      throw Error.missingQueryItems
    }
    
    self.kind = try URIParser.kind(from: otpType, items: queryItems)
    
    guard let encodedSecret = queryItems[.secret] else {
      throw Error.missingSecret
    }
    
    self.secret = try OneTimePassword.Secret(base32Encoded: encodedSecret)
    
    // The following values are optional and have fallback values.
    self.algorithm = URIParser.algorithm(for: queryItems[.algorithm])
    self.codeLength = try URIParser.codeLength(for: queryItems[.digits])
  }
}

// MARK: - Helpers

extension URIParser {
  /// Checks whether the scheme of the URI is valid.
  /// - Parameter value: The value of the URI scheme.
  /// - Returns: A `Bool` indicating whether the URI has a valid scheme.
  static func isValidScheme(_ value: String) -> Bool {
    value == scheme
  }
  
  /// Gets the kind of the OTP from the URI.
  ///
  /// - Note: This value is required to generate an OTP.
  /// A counter value is also required for counter based generators, same goes for a timestep (or period) value for time based generators.
  /// - Parameters:
  ///   - otpType: The `String` value of the otp type in the URI.
  ///   - items: The query items of the URI.
  /// - Returns: A `Kind` describing the type of OTP.
  static func kind(from otpType: String, items: [URLQueryItem]) throws -> OneTimePassword.Kind {
    guard let kindKey = OneTimePassword.Kind.Key(rawValue: otpType) else {
      throw Error.invalidOTPType
    }
    
    switch kindKey {
      case .hotp:
        guard let counterValue = items[.counter], let counter = UInt64(counterValue) else {
          throw Error.missingCounter
        }
        
        return .counterBased(counter: counter)
        
      case .totp:
        guard let periodValue = items[.period], let period = TimeInterval(periodValue) else {
          throw Error.missingPeriod
        }
        
        return .timeBased(timestep: period)
    }
  }
  
  /// Gets the algorithm to use to generate the OTP.
  /// - Parameter value: The `String` value representing the name of the algorithm.
  /// - Returns: A `Algorithm` object describint the algorithm to use for OTP generation.
  static func algorithm(for value: String?) -> OneTimePassword.Algorithm {
    guard let value = value else {
      return .sha1
    }
    
    return OneTimePassword.Algorithm.from(value)
  }
  
  /// Gets the length in digits of the OTP that should be generated.
  /// - Parameter value: The `String` value representing the number of digits.
  /// - Returns: A `Int` representing the number of digits forming the OTP code.
  static func codeLength(for value: String?) throws -> OneTimePassword.Length {
    guard let value = value, let digitsCount = Int(value) else {
      return .six
    }

    return try OneTimePassword.Length.from(digitsCount)
  }
}

// MARK: - Errors

extension URIParser {
  /// The possible errors of `URIParser`.
  enum Error: Swift.Error {
    /// The URI is invalid.
    case invalidURI
    
    /// The URI is missing a scheme.
    case missingScheme
    
    /// The scheme of the URI is invalid.
    case invalidScheme
    
    /// The URI is missing the type of OTP.
    case missingOTPType
    
    /// The OTP type in the URI is invalid.
    case invalidOTPType
    
    /// The URI is missing its query items.
    case missingQueryItems
    
    /// The URI query items are missing the secret string.
    case missingSecret
    
    /// The URI query items are missing the counter value. Counter is required for counter based generators, which generate HOTPs.
    case missingCounter
  
    /// The URI query items are missing the period value. Period is required for time based generators, which generate TOTPs.
    case missingPeriod
  }
}