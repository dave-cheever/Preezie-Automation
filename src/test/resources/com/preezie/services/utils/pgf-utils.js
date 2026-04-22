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

  // ========== getIntentSummary Prompt Arguments ==========
  // Fields: userPrompt, chatHistory, productRecommendationHistory, lastDiscussedProduct
  getIntentSummaryPromptArguments: function(item) {
      if (!item || !item.promptContent || !item.promptContent.arguments) return null;
      var args = item.promptContent.arguments;
      return {
        userPrompt: args.userPrompt || '',
        chatHistory: args.chatHistory || '',
        productRecommendationHistory: args.productRecommendationHistory || '',
        lastDiscussedProduct: args.lastDiscussedProduct || ''
      };
    },

    getFirstIntentSummaryPromptArguments: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var obj = this.getIntentSummaryPromptArguments(arr[i]);
          if (obj) return obj;
        }
        return null;
      },

  // ========== getIntent Prompt Arguments ==========
  // Fields: userPrompt, brandOverview, choices
  getIntentPromptArguments: function(item) {
      if (!item || !item.promptContent || !item.promptContent.arguments) return null;
      var args = item.promptContent.arguments;
      return {
        userPrompt: args.userPrompt || '',
        brandOverview: args.brandOverview || '',
        choices: args.choices || ''
      };
    },

    getFirstIntentPromptArguments: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var obj = this.getIntentPromptArguments(arr[i]);
          if (obj) return obj;
        }
        return null;
      },

  // ========== getCategories Prompt Arguments ==========
  // Fields: userPrompt, brandOverview, lastDiscussedCategories
  getCategoriesPromptArguments: function(item) {
      if (!item || !item.promptContent || !item.promptContent.arguments) return null;
      var args = item.promptContent.arguments;
      return {
        userPrompt: args.userPrompt || '',
        brandOverview: args.brandOverview || '',
        lastDiscussedCategories: args.lastDiscussedCategories || ''
      };
    },

    getFirstCategoriesPromptArguments: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var obj = this.getCategoriesPromptArguments(arr[i]);
          if (obj) return obj;
        }
        return null;
      },

  // ========== findProductFromPrompt Prompt Arguments ==========
  // Fields: userPrompt, genders, dynamicVariantFields
  getFindProductPromptArguments: function(item) {
      if (!item || !item.promptContent || !item.promptContent.arguments) return null;
      var args = item.promptContent.arguments;
      return {
        userPrompt: args.userPrompt || '',
        genders: args.genders || '',
        dynamicVariantFields: args.dynamicVariantFields || ''
      };
    },

    getFirstFindProductPromptArguments: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var obj = this.getFindProductPromptArguments(arr[i]);
          if (obj) return obj;
        }
        return null;
      },

  // Legacy function (kept for backward compatibility) - returns concatenated string
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
      },

    // Get just the userPrompt from promptContent.arguments (not combined with other fields)
    getUserPromptOnly: function(item) {
        if (!item || !item.promptContent || !item.promptContent.arguments) return null;
        var userPrompt = item.promptContent.arguments.userPrompt;
        if (userPrompt === undefined || userPrompt === null) return null;
        if (typeof userPrompt !== 'string') userPrompt = String(userPrompt);
        var trimmed = userPrompt.trim();
        return trimmed.length ? trimmed : null;
      },

    getFirstUserPromptOnly: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var txt = this.getUserPromptOnly(arr[i]);
          if (txt) return txt;
        }
        return null;
      },

  // ========== smartResponse Prompt Arguments ==========
  // Fields: userPrompt, baseProduct, products
  getSmartResponsePromptArguments: function(item) {
      if (!item || !item.promptContent || !item.promptContent.arguments) return null;
      var args = item.promptContent.arguments;
      return {
        userPrompt: args.userPrompt || '',
        baseProduct: args.baseProduct || '',
        products: args.products || ''
      };
    },

    getFirstSmartResponsePromptArguments: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var obj = this.getSmartResponsePromptArguments(arr[i]);
          if (obj) return obj;
        }
        return null;
      },

  // ========== getUserInformation Prompt Arguments ==========
  // Fields: userPrompt, brandOverview
  getUserInformationPromptArguments: function(item) {
      if (!item || !item.promptContent || !item.promptContent.arguments) return null;
      var args = item.promptContent.arguments;
      return {
        userPrompt: args.userPrompt || '',
        brandOverview: args.brandOverview || ''
      };
    },

    getFirstUserInformationPromptArguments: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var obj = this.getUserInformationPromptArguments(arr[i]);
          if (obj) return obj;
        }
        return null;
      },

  // ========== getSpecificQuestionSubIntent Prompt Arguments ==========
  // Fields: userPrompt, brandOverview (may vary based on actual implementation)
  getSpecificQuestionSubIntentPromptArguments: function(item) {
      if (!item || !item.promptContent || !item.promptContent.arguments) return null;
      var args = item.promptContent.arguments;
      return {
        userPrompt: args.userPrompt || '',
        brandOverview: args.brandOverview || '',
        choices: args.choices || ''
      };
    },

    getFirstSpecificQuestionSubIntentPromptArguments: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var obj = this.getSpecificQuestionSubIntentPromptArguments(arr[i]);
          if (obj) return obj;
        }
        return null;
      },

  // ========== getMultiProductQuestionSubIntent Prompt Arguments ==========
  // Fields: userPrompt, brandOverview (may vary based on actual implementation)
  getMultiProductQuestionSubIntentPromptArguments: function(item) {
      if (!item || !item.promptContent || !item.promptContent.arguments) return null;
      var args = item.promptContent.arguments;
      return {
        userPrompt: args.userPrompt || '',
        brandOverview: args.brandOverview || '',
        choices: args.choices || ''
      };
    },

    getFirstMultiProductQuestionSubIntentPromptArguments: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var obj = this.getMultiProductQuestionSubIntentPromptArguments(arr[i]);
          if (obj) return obj;
        }
        return null;
      },

  // ========== specificProductQuestion Prompt Arguments ==========
  // Fields: userPrompt, brandOverview, product (may vary based on actual implementation)
  getSpecificProductQuestionPromptArguments: function(item) {
      if (!item || !item.promptContent || !item.promptContent.arguments) return null;
      var args = item.promptContent.arguments;
      return {
        userPrompt: args.userPrompt || '',
        brandOverview: args.brandOverview || '',
        product: args.product || '',
        choices: args.choices || ''
      };
    },

    getFirstSpecificProductQuestionPromptArguments: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var obj = this.getSpecificProductQuestionPromptArguments(arr[i]);
          if (obj) return obj;
        }
        return null;
      },

  // ========== searchingByTitle Prompt Arguments ==========
  // Fields: userPrompt, brandOverview (may vary based on actual implementation)
  getSearchingByTitlePromptArguments: function(item) {
      if (!item || !item.promptContent || !item.promptContent.arguments) return null;
      var args = item.promptContent.arguments;
      return {
        userPrompt: args.userPrompt || '',
        brandOverview: args.brandOverview || '',
        choices: args.choices || ''
      };
    },

    getFirstSearchingByTitlePromptArguments: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var obj = this.getSearchingByTitlePromptArguments(arr[i]);
          if (obj) return obj;
        }
        return null;
      },

  // ========== specificProductQuestionResponse Prompt Arguments ==========
  // Fields: userPrompt, brandOverview, product (may vary based on actual implementation)
  getSpecificProductQuestionResponsePromptArguments: function(item) {
      if (!item || !item.promptContent || !item.promptContent.arguments) return null;
      var args = item.promptContent.arguments;
      return {
        userPrompt: args.userPrompt || '',
        brandOverview: args.brandOverview || '',
        product: args.product || '',
        choices: args.choices || ''
      };
    },

    getFirstSpecificProductQuestionResponsePromptArguments: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var obj = this.getSpecificProductQuestionResponsePromptArguments(arr[i]);
          if (obj) return obj;
        }
        return null;
      },

  // ========== specificProductSizeRecommendation Prompt Arguments ==========
  // Fields: userProfile, toneOfVoice, brandOverview, userInput, productSizeData, productName
  getSpecificProductSizeRecommendationPromptArguments: function(item) {
      if (!item || !item.promptContent || !item.promptContent.arguments) return null;
      var args = item.promptContent.arguments;
      return {
        userProfile: args.userProfile || '',
        toneOfVoice: args.toneOfVoice || '',
        brandOverview: args.brandOverview || '',
        userInput: args.userInput || '',
        productSizeData: args.productSizeData || '',
        productName: args.productName || ''
      };
    },

    getFirstSpecificProductSizeRecommendationPromptArguments: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var obj = this.getSpecificProductSizeRecommendationPromptArguments(arr[i]);
          if (obj) return obj;
        }
        return null;
      },

  // ========== similarBaseProduct Prompt Arguments ==========
  // Fields: userPrompt, productRecommendationHistory, productTitle, productId
  getSimilarBaseProductPromptArguments: function(item) {
      if (!item || !item.promptContent || !item.promptContent.arguments) return null;
      var args = item.promptContent.arguments;
      return {
        userPrompt: args.userPrompt || '',
        productRecommendationHistory: args.productRecommendationHistory || '',
        productTitle: args.productTitle || '',
        productId: args.productId || ''
      };
    },

    getFirstSimilarBaseProductPromptArguments: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var obj = this.getSimilarBaseProductPromptArguments(arr[i]);
          if (obj) return obj;
        }
        return null;
      },

  // ========== productCompareResponse Prompt Arguments ==========
  // Fields: userPrompt, productRecommendationHistory, productTitle, productId
  getProductCompareResponsePromptArguments: function(item) {
      if (!item || !item.promptContent || !item.promptContent.arguments) return null;
      var args = item.promptContent.arguments;
      return {
        userPrompt: args.userPrompt || '',
        productRecommendationHistory: args.productRecommendationHistory || '',
        productTitle: args.productTitle || '',
        productId: args.productId || ''
      };
    },

    getFirstProductCompareResponsePromptArguments: function(listOrItem) {
        var arr = listOrItem;
        if (!arr) return null;
        if (!Array.isArray(arr)) arr = [arr];
        for (var i = 0; i < arr.length; i++) {
          var obj = this.getProductCompareResponsePromptArguments(arr[i]);
          if (obj) return obj;
        }
        return null;
      }
})