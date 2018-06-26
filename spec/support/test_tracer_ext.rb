module Test
  class Span < OpenTracing::Span
    def log_kv(*attributes)
      log(*attributes)
    end
  end
end
