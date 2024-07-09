local logger = require("parrot.logger")

local Gemini = {}
Gemini.__index = Gemini

local available_model_set = {
  ["gemini-1.5-flash"] = true,
  ["gemini-1.5-pro"] = true,
}

function Gemini:new(endpoint, api_key)
  return setmetatable({
    endpoint = endpoint,
    api_key = api_key,
    name = "gemini",
    _model = nil,
  }, self)
end

function Gemini:set_model(model)
  local _model = type(model) == "string" and model or model.model
  self._model = _model
end

function Gemini:curl_params()
  return {
    self.endpoint .. self._model .. ":streamGenerateContent",
    "-H",
    "x-goog-api-key: " .. self.api_key,
    "-X",
    "POST",
  }
end

function Gemini:adjust_payload(payload)
  payload.model = nil
  payload.stream = nil
  payload.temperature = nil
  payload.top_p = nil

  local new_messages = {}

  for _, message in ipairs(payload.messages) do
    -- restrive system prompt from messages and inject it into the payload
    -- remove this message
    if message.role == "system" then
      if message.parts and message.parts.text then
        payload.system_instruction = { parts = { text = message.parts.text:gsub("^%s*(.-)%s*$", "%1") } }
      end
    else
      table.insert(new_messages, message)
    end
  end
  payload.contents = vim.deepcopy(new_messages)
  payload.messages = nil
  return payload
end

function Gemini:verify()
  if type(self.api_key) == "table" then
    logger.error("api_key is still an unresolved command: " .. vim.inspect(self.api_key))
    return false
  elseif self.api_key and string.match(self.api_key, "%S") then
    return true
  else
    logger.error("Error with api key " .. self.name .. " " .. vim.inspect(self.api_key) .. " run :checkhealth parrot")
    return false
  end
end

function Gemini:preprocess_messages(messages)
  local new_messages = {}
  for _, message in ipairs(messages) do
    local _role = ""
    if message.role == "assistant" then
      _role = "model"
    else
      _role = message.role
    end
    if message.content then
      table.insert(new_messages, { parts = { { text = message.content:gsub("^%s*(.-)%s*$", "%1") } }, role = _role })
    end
  end
  return new_messages
end

function Gemini:add_system_prompt(messages, _)
  return messages
end

function Gemini:process(line)
  -- print("LINE", vim.inspect(line))
  local pattern = '"text":%s*"(.-)"\'?'
  if line:match("tex") then
    -- print("LINE MATCH", vim.inspect(line))
    local match = line:match(pattern)
    -- print("RAW", match)
    if match then
      match = match:gsub("\\n", "\n")
      match = match:gsub('\\"', '"')
      match = match:gsub("\\'", "'")
      match = match:gsub("\\\\", "\\")
      return match
    end
  end
end

function Gemini:check(agent)
  local model = type(agent.model) == "string" and agent.model or agent.model.model
  return available_model_set[model]
end

return Gemini
