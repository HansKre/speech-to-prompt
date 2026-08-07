import Foundation

enum LLMState {
    case idle
    case loading
    case success(String)
    case failure(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

class LLMManager: ObservableObject {
    @Published var state: LLMState = .idle
    @Published var improvedPrompt: String? = nil
    @Published var configError: String? = nil
    
    struct LLMConfig: Codable {
        let apiType: String
        let apiUrl: String
        let apiKey: String
        let model: String
        let apiVersion: String?
    }
    
    struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    struct AzureRequestBody: Codable {
        let messages: [ChatMessage]
    }

    struct OpenAIRequestBody: Codable {
        let model: String
        let messages: [ChatMessage]
    }

    struct LLMResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let role: String
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }
    
    func loadConfig() -> LLMConfig? {
        return loadConfigFromUserDefaults()
    }
    
    func loadConfigFromUserDefaults() -> LLMConfig? {
        let defaults = UserDefaults.standard
        guard let apiType = defaults.string(forKey: "LLM_apiType"),
              let apiUrl = defaults.string(forKey: "LLM_apiUrl"),
              let apiKey = defaults.string(forKey: "LLM_apiKey"),
              let model = defaults.string(forKey: "LLM_model") else {
            return nil
        }
        
        if apiUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        
        let apiVersion = defaults.string(forKey: "LLM_apiVersion") ?? "2024-10-21"
        return LLMConfig(
            apiType: apiType,
            apiUrl: apiUrl,
            apiKey: apiKey,
            model: model,
            apiVersion: apiVersion
        )
    }
    
    
    func improvePrompt(text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                self.state = .failure("Transcription text is empty.")
            }
            return
        }
        
        await MainActor.run {
            self.state = .loading
            self.configError = nil
        }
        
        guard let config = loadConfig() else {
            await MainActor.run {
                let errorMsg = "Credentials configuration required. Please open Settings (gear icon) in the top-right to configure your AI endpoint and key."
                self.state = .failure(errorMsg)
                self.configError = errorMsg
            }
            return
        }
        
        if config.apiKey.starts(with: "YOUR_") || config.apiUrl.contains("YOUR_") {
            await MainActor.run {
                let errorMsg = "Credentials configuration required. Please open Settings (gear icon) in the top-right to configure your AI endpoint and key."
                self.state = .failure(errorMsg)
                self.configError = errorMsg
            }
            return
        }
        
        do {
            let refinedText = try await sendLLMRequest(config: config, promptText: text)
            await MainActor.run {
                self.improvedPrompt = refinedText
                self.state = .success(refinedText)
            }
        } catch {
            await MainActor.run {
                self.state = .failure("LLM Request failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendLLMRequest(config: LLMConfig, promptText: String) async throws -> String {
        let systemPrompt = """
        You are an expert copywriter and prompt editor. Your task is to clean up, polish, and optimize a user's transcribed speech input into a clear, structured, and highly effective prompt.

        Analyze the user's input, which may contain stutters, repetitions, filler words, or poorly structured speech-to-text phrasing.

        Produce a refined version that is:
        1. Concise and direct (eliminates filler words, stutters, and thinking-aloud phrasing).
        2. Well-structured, using clear markdown elements if helpful (e.g., bullet points for requirements, code blocks for code snippets).
        3. Explicit about instructions, goals, context, and constraints.
        4. Professional in tone.

        CRITICAL RULES:
        - DO NOT add any calls to action, verification tasks, questions, or instructions that were not explicitly present in the original raw input.
        - DO NOT invent, assume, or append new tasks (such as "Verify if these figures are accurate", "Identify the likely data source", or asking for explanations) if the user did not explicitly request them.
        - Keep the content, meaning, facts, and intent of the original text exactly as it was, only polishing the delivery, structure, and readability.

        Do not add any preamble (like "Here is your refined prompt:") or postamble. Output ONLY the refined text itself, ready to be copied and pasted.
        """

        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: promptText)
        ]

        return try await sendGenericLLMRequest(config: config, messages: messages)
    }
    
    func translateToEnglish(text: String) async -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return text
        }

        guard let config = loadConfig() else {
            return text
        }

        let systemPrompt = """
        You are a language detection and translation assistant.

        1. Detect the language of the user's input.
        2. If the input is already in English, output it exactly as-is with no changes.
        3. If the input is NOT in English, translate it to English accurately, preserving the original meaning, tone, and structure.

        Output ONLY the final text (either the original English or the translated English). Do not add any preamble, explanation, or labels.
        """

        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: text)
        ]

        do {
            let translated = try await sendGenericLLMRequest(config: config, messages: messages)
            return translated
        } catch {
            DiagnosticsManager.shared.log("Translation failed: \(error.localizedDescription)")
            return text
        }
    }

    private func sendGenericLLMRequest(config: LLMConfig, messages: [ChatMessage]) async throws -> String {
        var requestUrlString = config.apiUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let headers: [String: String]
        let bodyData: Data

        if config.apiType.lowercased() == "azure" {
            let version = config.apiVersion ?? "2024-10-21"
            requestUrlString += "/openai/deployments/\(config.model)/chat/completions?api-version=\(version)"
            headers = [
                "api-key": config.apiKey,
                "Content-Type": "application/json"
            ]
            let body = AzureRequestBody(messages: messages)
            bodyData = try JSONEncoder().encode(body)
        } else {
            requestUrlString += "/chat/completions"
            headers = [
                "Authorization": "Bearer \(config.apiKey)",
                "Content-Type": "application/json"
            ]
            let body = OpenAIRequestBody(model: config.model, messages: messages)
            bodyData = try JSONEncoder().encode(body)
        }

        guard let url = URL(string: requestUrlString) else {
            throw NSError(domain: "LLMManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL constructed: \(requestUrlString)"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let bodyString = String(data: data, encoding: .utf8) ?? "No response body"
            throw NSError(domain: "LLMManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Status \(httpResponse.statusCode): \(bodyString)"])
        }

        let llmResponse = try JSONDecoder().decode(LLMResponse.self, from: data)
        guard let resultText = llmResponse.choices.first?.message.content else {
            throw NSError(domain: "LLMManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Empty choices returned from LLM."])
        }

        return resultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func clearImprovedPrompt() {
        self.improvedPrompt = nil
        self.state = .idle
    }
}
