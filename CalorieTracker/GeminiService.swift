import Foundation


@Observable
final class GeminiService {
    static let shared = GeminiService()
    
    // Allows the user to change the API key in settings or input it on first launch
    var apiKey: String {
        get {
            UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "gemini_api_key")
        }
    }
    
    var hasApiKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private init() {
        // Attempt to load from Config.plist if present
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let key = dict["GeminiAPIKey"] as? String,
           !key.isEmpty && !key.contains("YOUR_API_KEY") {
            UserDefaults.standard.set(key, forKey: "gemini_api_key")
        }
    }
    

    func calculateGoals(
        goal: String,
        gender: String,
        age: Int,
        heightCm: Double,
        weightKg: Double,
        activityLevel: String,
        weeklyApproachLbs: Double
    ) async throws -> AICalculatedGoals {
        guard hasApiKey else {
            throw NSError(domain: "GeminiService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gemini API Key is missing. Please add it in settings."])
        }
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "GeminiService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL."])
        }
        
        let systemInstruction = """
        You are an expert fitness and nutrition coach. Calculate the user's daily caloric maintenance (TDEE) and target macronutrient goals (protein, carbs, and fat in grams) based on their profile.
        Return the calculations in raw JSON format matching the schema requested.
        """
        
        let prompt = """
        Please calculate goals for:
        - Goal: \(goal)
        - Gender: \(gender)
        - Age: \(age)
        - Height: \(heightCm) cm
        - Weight: \(weightKg) kg
        - Activity Level: \(activityLevel)
        - Target weekly weight change: \(weeklyApproachLbs) lbs
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "\(systemInstruction)\n\n\(prompt)"]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "OBJECT",
                    "properties": [
                        "maintenanceCalories": ["type": "INTEGER", "description": "Estimated daily maintenance calories (TDEE) in kcal"],
                        "surplusOrDeficit": ["type": "INTEGER", "description": "Daily caloric adjustment (negative for deficit, positive for surplus, 0 for maintenance)"],
                        "targetCalories": ["type": "INTEGER", "description": "Daily target calories in kcal"],
                        "proteinGrams": ["type": "NUMBER", "description": "Suggested protein intake in grams"],
                        "carbsGrams": ["type": "NUMBER", "description": "Suggested carbohydrate intake in grams"],
                        "fatGrams": ["type": "NUMBER", "description": "Suggested fat intake in grams"],
                        "summaryExplanation": ["type": "STRING", "description": "A short, encouraging summary explanation of the suggested plan."]
                    ],
                    "required": ["maintenanceCalories", "surplusOrDeficit", "targetCalories", "proteinGrams", "carbsGrams", "fatGrams", "summaryExplanation"]
                ]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw NSError(domain: "GeminiService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body."])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GeminiService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server."])
        }
        
        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorDict = errorJson["error"] as? [String: Any],
               let message = errorDict["message"] as? String {
                throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }
            throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(httpResponse.statusCode)"])
        }
        
        struct GeminiResponse: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    struct Part: Codable {
                        let text: String
                    }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }
        
        let decoder = JSONDecoder()
        let geminiResult = try decoder.decode(GeminiResponse.self, from: data)
        
        guard let jsonText = geminiResult.candidates.first?.content.parts.first?.text else {
            throw NSError(domain: "GeminiService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not retrieve text from response."])
        }
        
        guard let jsonTextData = jsonText.data(using: .utf8) else {
            throw NSError(domain: "GeminiService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not convert response text to data."])
        }
        
        let parsedGoals = try decoder.decode(AICalculatedGoals.self, from: jsonTextData)
        return parsedGoals
    }
}

struct AICalculatedGoals: Codable {
    let maintenanceCalories: Int
    let surplusOrDeficit: Int
    let targetCalories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let summaryExplanation: String
}
