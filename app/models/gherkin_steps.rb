# Turns a step field's text, one step per line, into Gherkin step lines indented
# relative to the step itself.
module GherkinSteps
  KEYWORD = /\A(?:(?:Given|When|Then|And|But) |\* )/
  DOC_STRING_FENCE = /\A(?:"""|```)/

  module_function

  def lines(text, keyword)
    steps = 0
    in_doc_string = false
    text.to_s.gsub(/\r\n?/, "\n").split("\n").filter_map do |raw|
      line = raw.rstrip
      stripped = line.lstrip
      if in_doc_string
        in_doc_string = !stripped.match?(DOC_STRING_FENCE)
        line.empty? ? "" : "  #{in_doc_string ? line : stripped}"
      elsif stripped.match?(DOC_STRING_FENCE)
        in_doc_string = true
        "  #{stripped}"
      elsif stripped.empty?
        nil
      elsif stripped.start_with?("|")
        "  #{stripped}"
      else
        step = stripped.match?(KEYWORD) ? stripped : "#{steps.zero? ? keyword : 'And'} #{stripped}"
        steps += 1
        step
      end
    end
  end
end
