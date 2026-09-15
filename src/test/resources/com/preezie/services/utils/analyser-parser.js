(function() {
  
  function parseAnalysis(analysisHtml) {
    if (!analysisHtml) {
      return {
        result: 'Unknown',
        intent: '',
        pipelineValidation: '',
        anomalies: '',
        qualityAssessment: '',
        rawAnalysis: '',
        parseError: 'Analysis HTML is null or empty'
      };
    }

    var parsed = {
      result: 'Unknown',
      intent: '',
      pipelineValidation: '',
      anomalies: '',
      qualityAssessment: '',
      rawAnalysis: analysisHtml,
      parseError: null
    };

    try {
      // Strip HTML tags for easier parsing
      var plainText = stripHtmlTags(analysisHtml);

      // Extract Result (Pass or Fail)
      var resultMatch = plainText.match(/Result\s*\n\s*(Pass|Fail)/i);
      if (resultMatch) {
        parsed.result = resultMatch[1];
      }

      // Extract Intent section
      var intentMatch = plainText.match(/Intent\s*\n([^\n]+(?:\n(?!Pipeline Validation|Anomalies|Response Quality)[^\n]+)*)/i);
      if (intentMatch) {
        parsed.intent = intentMatch[1].trim();
      }

      // Extract Pipeline Validation section
      var pipelineMatch = plainText.match(/Pipeline Validation\s*\n([^\n]+(?:\n(?!Anomalies|Response Quality)[^\n]+)*)/i);
      if (pipelineMatch) {
        parsed.pipelineValidation = pipelineMatch[1].trim();
      }

      // Extract Anomalies & Issues section
      var anomaliesMatch = plainText.match(/Anomalies\s*&\s*Issues\s*\n([^\n]+(?:\n(?!Response Quality)[^\n]+)*)/i);
      if (anomaliesMatch) {
        parsed.anomalies = anomaliesMatch[1].trim();
      }

      // Extract Response Quality Assessment section
      var qualityMatch = plainText.match(/Response Quality Assessment\s*\n(.+?)(?=\n\n|\n*$)/is);
      if (qualityMatch) {
        parsed.qualityAssessment = qualityMatch[1].trim();
      }

    } catch (e) {
      parsed.parseError = 'Error parsing analysis: ' + e.message;
    }

    return parsed;
  }

  function stripHtmlTags(html) {
    if (!html) return '';
    
    var text = html
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'");
    
    text = text.replace(/<[^>]+>/g, '');
    text = text.replace(/\s+/g, ' ').trim();
    
    text = text
      .replace(/Result\s+/g, 'Result\n')
      .replace(/Intent\s+/g, '\nIntent\n')
      .replace(/Pipeline Validation\s+/g, '\nPipeline Validation\n')
      .replace(/Anomalies\s*&\s*Issues\s+/g, '\nAnomalies & Issues\n')
      .replace(/Response Quality Assessment\s+/g, '\nResponse Quality Assessment\n');
    
    return text;
  }

  function getAnalysisSummary(parsedAnalysis) {
    if (!parsedAnalysis) return 'No analysis available';
    
    var summary = 'Result: ' + parsedAnalysis.result;
    
    if (parsedAnalysis.intent) {
      summary += '\nIntent: ' + parsedAnalysis.intent.substring(0, 100);
      if (parsedAnalysis.intent.length > 100) summary += '...';
    }
    
    if (parsedAnalysis.result === 'Fail' && parsedAnalysis.anomalies && parsedAnalysis.anomalies !== '—') {
      summary += '\nAnomalies: ' + parsedAnalysis.anomalies.substring(0, 100);
      if (parsedAnalysis.anomalies.length > 100) summary += '...';
    }
    
    return summary;
  }

  function isPassingResult(parsedAnalysis) {
    if (!parsedAnalysis) return false;
    return parsedAnalysis.result && parsedAnalysis.result.toLowerCase() === 'pass';
  }

  // Return public API
  return {
    parseAnalysis: parseAnalysis,
    stripHtmlTags: stripHtmlTags,
    getAnalysisSummary: getAnalysisSummary,
    isPassingResult: isPassingResult
  };
  
})()
