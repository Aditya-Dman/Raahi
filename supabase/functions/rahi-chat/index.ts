import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const systemPrompt = `
You are Raahi, the intelligent safety assistant inside the Raahi tourist-safety
mobile app. You are a real generative assistant: understand the user's intent,
ask a short clarifying question when needed, and produce a tailored answer.

You know these actual Raahi features:
- Home dashboard with safety tools.
- GPS route tracking: the user taps Start on My location, the app records
  meaningful GPS points, draws the travelled route as a blue line, shows
  distance and duration, and Stop ends tracking. The route is retained locally.
- Emergency alerts: SOS, medical assistance, security assistance, and sharing
  current location. Emergency contacts can be managed in the app.
- Digital tourist identity: the signed-in user's identity card and digital ID.
- The assistant itself.

Give practical, calm, concise guidance. Never claim that you contacted police,
emergency services, a contact, or changed app data unless the app explicitly
reports that action as completed. For a possible immediate danger, advise the
user to call local emergency services and use the Raahi SOS flow. If a user is
lost outdoors, prioritize immediate safety, conserving battery, staying put
when appropriate, sharing location, and contacting trusted people.
Do not invent GPS coordinates, route data, medical diagnoses, or app features.
When analyzing a food or plant photo, never guarantee that it is edible. Explain
that visual identification is uncertain and recommend local expert confirmation.
When analyzing a wound photo, never diagnose or estimate severity with certainty.
Describe visible concerns cautiously, give basic first-aid guidance, and advise
urgent professional care for red flags.
The app may provide a context object with current screen and user details.
Use it only to make the response more relevant.
`;

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await request.json();
    const messages = Array.isArray(body.messages)
      ? body.messages
          .filter(
            (message) =>
              message &&
              (message.role === "user" || message.role === "assistant") &&
              typeof message.content === "string",
          )
          .map((message) => ({
            role: message.role,
            content: message.content.trim().slice(0, 4000),
          }))
          .filter((message) => message.content.length > 0)
      : [];
    const context = body.context ?? {};
    const imageBase64 =
      typeof body.image_base64 === "string" ? body.image_base64 : null;
    const imageMimeType =
      typeof body.image_mime_type === "string"
        ? body.image_mime_type
        : "image/jpeg";

    if (messages.length === 0 || messages.length > 20) {
      return json({ error: "Provide between 1 and 20 valid messages." }, 400);
    }
    if (imageBase64 && imageBase64.length > 8_000_000) {
      return json({ error: "That image is too large. Choose a smaller image." }, 413);
    }

    const apiKey = Deno.env.get("GROQ_API_KEY");
    if (!apiKey) {
      return json({ error: "The Raahi AI service is not configured yet." }, 503);
    }

    const modelResponse = await fetch("https://api.groq.com/openai/v1/models", {
      headers: {
        Authorization: "Bearer " + apiKey,
      },
    });
    const modelResult = await modelResponse.json();
    if (!modelResponse.ok || !Array.isArray(modelResult.data)) {
      console.error("Groq model listing failed", modelResult);
      return json(
        { error: "Groq rejected the API key while listing available models." },
        502,
      );
    }

    const preferredModels = [
      "qwen/qwen3.8-27b",
      "llama-3.1-8b-instant",
      "llama-3.3-70b-versatile",
      "openai/gpt-oss-20b",
      "openai/gpt-oss-120b",
    ];
    const availableModels = modelResult.data
      .map((model: { id?: string }) => model.id)
      .filter((id: unknown): id is string => typeof id === "string");
    const isVisionModel = (candidate: string) =>
      candidate.includes("vision") ||
      candidate.includes("scout") ||
      candidate.includes("maverick") ||
      candidate.includes("qwen3.8-27b");
    const model = imageBase64
      ? availableModels.find(isVisionModel)
      : preferredModels.find((candidate) => availableModels.includes(candidate)) ??
        availableModels.find(
          (candidate) =>
            !candidate.includes("whisper") &&
            !candidate.includes("guard") &&
            !candidate.includes("tts"),
        );

    if (!model) {
      return json(
        {
          error: imageBase64
            ? "Photo analysis is unavailable because this Groq API key has no accessible vision model."
            : "No compatible Groq text model is available.",
        },
        502,
      );
    }

    const latestMessage = messages[messages.length - 1];
    const userContent = imageBase64
      ? [
          {
            type: "text",
            text:
              latestMessage.content ||
              "Please analyze this image for travel safety.",
          },
          {
            type: "image_url",
            image_url: {
              url: `data:${imageMimeType};base64,${imageBase64}`,
            },
          },
        ]
      : latestMessage.content;
    const chatMessages = [
      { role: "system", content: systemPrompt },
      {
        role: "system",
        content: `Current Raahi context (may be incomplete): ${JSON.stringify(context)}`,
      },
      ...messages.slice(0, -1),
      { role: "user", content: userContent },
    ];

    const groqResponse = await fetch(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer " + apiKey,
        },
        body: JSON.stringify({
          model,
          temperature: 0.35,
          max_tokens: 700,
          messages: chatMessages.slice(-14),
        }),
      },
    );

    const result = await groqResponse.json();
    if (!groqResponse.ok) {
      console.error("Groq request failed", result);
      const providerMessage =
        typeof result?.error?.message === "string"
          ? result.error.message
          : "The Groq request was rejected.";
      return json(
        {
          error: `Groq rejected the request (${groqResponse.status}): ${providerMessage}`,
        },
        502,
      );
    }

    const answer = result.choices?.[0]?.message?.content?.trim();
    if (typeof answer !== "string" || answer.trim().length === 0) {
      return json({ error: "The AI returned an empty response." }, 502);
    }

    return json({ message: answer.trim() });
  } catch (error) {
    console.error("Raahi chat error", error);
    return json({ error: "Unable to process that message right now." }, 500);
  }
});

function json(payload: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
