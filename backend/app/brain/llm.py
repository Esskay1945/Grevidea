"""Bounded provider fallback, including runtime outages. Never log API keys."""
import httpx

class LLMChain:
    def __init__(self, settings, transport=None):
        self.settings = settings
        self.transport = transport
        self.active = "none"

    @property
    def providers(self):
        s = self.settings
        return [name for name, enabled in [
            ("gemini", s.gemini_enabled and s.gemini_api_key),
            ("groq", s.groq_enabled and s.groq_api_key),
            ("ollama", s.ollama_enabled),
            ("mistral", s.mistral_enabled and s.mistral_api_key),
        ] if enabled]

    async def chat(self, messages):
        s = self.settings
        if not self.providers:
            self.active = "none"
            raise RuntimeError("Climate Assistant is unavailable: no configured LLM provider.")
        async with httpx.AsyncClient(timeout=min(s.llm_timeout, 20), transport=self.transport) as client:
            for provider in self.providers:
                try:
                    if provider == "gemini":
                        system = "\n".join(m["content"] for m in messages if m["role"] == "system")
                        payload = {"contents": [{"role": "model" if m["role"] == "assistant" else "user", "parts": [{"text": m["content"]}]} for m in messages if m["role"] != "system"], "generationConfig": {"temperature": s.llm_temperature, "maxOutputTokens": s.llm_max_tokens}}
                        if system:
                            payload["systemInstruction"] = {"parts": [{"text": system}]}
                        response = await client.post(f"https://generativelanguage.googleapis.com/v1beta/models/{s.gemini_model}:generateContent", headers={"x-goog-api-key": s.gemini_api_key}, json=payload)
                        response.raise_for_status()
                        text = "".join(p.get("text", "") for p in response.json()["candidates"][0]["content"]["parts"])
                    elif provider == "ollama":
                        response = await client.post(f"{s.ollama_base_url}/api/chat", json={"model": s.ollama_model, "messages": messages, "stream": False, "options": {"temperature": s.llm_temperature, "num_predict": s.llm_max_tokens}})
                        response.raise_for_status()
                        text = response.json()["message"]["content"]
                    else:
                        url = "https://api.groq.com/openai/v1/chat/completions" if provider == "groq" else "https://api.mistral.ai/v1/chat/completions"
                        key = s.groq_api_key if provider == "groq" else s.mistral_api_key
                        model = s.groq_model if provider == "groq" else s.mistral_model
                        response = await client.post(url, headers={"Authorization": f"Bearer {key}"}, json={"model": model, "messages": messages, "temperature": s.llm_temperature, "max_tokens": s.llm_max_tokens})
                        response.raise_for_status()
                        text = response.json()["choices"][0]["message"]["content"]
                    if not text.strip():
                        raise ValueError("Empty provider response")
                    self.active = provider
                    return text
                except (httpx.HTTPError, KeyError, IndexError, ValueError, TypeError):
                    continue
        self.active = "none"
        raise RuntimeError("Climate Assistant is unavailable: configure a working LLM provider and retry.")
