{
  meta = {
    description = "Local LLM runtime packages and integrations";
    requires.host = [];
    conflicts.host = [];
    targets = ["host"];
  };

  host = {
    packageTags = ["llm"];
  };
}
