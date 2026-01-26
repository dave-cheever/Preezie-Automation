// javascript
({
  findFirstValidPGF: function(list, propertyName) {
    var prop = propertyName || 'Safe';
    var arr = list;
    if (!arr) return null;
    if (!Array.isArray(arr)) arr = [arr];

    for (var i = 0; i < arr.length; i++) {
      var it = arr[i];
      var raw = it && it.promptContent && it.promptContent.llmResponseFormated;
      if (!raw) continue;

      try {
        var parsed = (typeof karate !== 'undefined' && karate.fromString)
          ? karate.fromString(raw)
          : JSON.parse(raw);

        if (!parsed) continue;

        if (prop === '*' || parsed[prop] !== undefined) {
          return { parsed: parsed, item: it };
        }
      } catch (e) {
        // ignore parse errors and continue
      }
    }
    return null;
  },

  getLLMResponseText: function(item) {
    if (!item || !item.promptContent) return null;
    var val = item.promptContent.llmResponseFormated;
    if (val === undefined || val === null) return null;
    if (typeof val !== 'string') val = String(val);
    var trimmed = val.trim();
    return trimmed.length ? trimmed : null;
  },

  getFirstLLMResponseText: function(listOrItem) {
    var arr = listOrItem;
    if (!arr) return null;
    if (!Array.isArray(arr)) arr = [arr];
    for (var i = 0; i < arr.length; i++) {
      var txt = this.getLLMResponseText(arr[i]);
      if (txt) return txt;
    }
    return null;
  },

  getLLMPromptArguments: function(item) {
      if (!item || !item.promptContent) return null;
      var userPrompt = item.promptContent.arguments.userPrompt;
      var chatHistory = item.promptContent.arguments.chatHistory;
      var productRecommendationHistory = item.promptContent.arguments.productRecommendationHistory;
      var lastDiscussedProduct = item.promptContent.arguments.lastDiscussedProduct;
      var val = userPrompt + ' ' + chatHistory + ' ' + productRecommendationHistory + ' ' + lastDiscussedProduct;
      if (val === undefined || val === null) return null;
      if (typeof val !== 'string') val = String(val);
      var trimmed = val.trim();
      return trimmed.length ? trimmed : null;
    },

    getFirstLLMPromptArgumentsText: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var txt = this.getLLMPromptArguments(arr[i]);
          if (txt) return txt;
        }
        return null;
      },

    getLLMRequestFormatedText: function(item) {
        if (!item || !item.promptContent) return null;
        var val = item.promptContent.llmRequestFormated;
        if (val === undefined || val === null) return null;
        if (typeof val !== 'string') val = String(val);
        var trimmed = val.trim();
        return trimmed.length ? trimmed : null;
      },

    getFirstLLMRequestFormatedText: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var txt = this.getLLMRequestFormatedText(arr[i]);
          if (txt) return txt;
        }
       return null;
      }
})