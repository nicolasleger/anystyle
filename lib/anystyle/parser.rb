module AnyStyle
  class ParserCore
    include StringUtils

    class << self
      attr_reader :defaults, :formats

      def load(path)
        new :model => path
      end

      # Returns a default parser instance
      def instance
        Thread.current["anystyle_#{name.downcase}"] ||= new
      end
    end

    attr_reader :model, :options, :features, :normalizers

    def initialize(options = {})
      @options = self.class.defaults.merge(options)
      load_model
    end

    def load_model(file = options[:model])
      unless file.nil?
        @model = Wapiti.load(file)
        @model.options.update_attributes options
      else
        @model = Wapiti::Model.new(options.reject { |k,_| k == :model })
        @model.path = options[:model]
      end

      self
    end

    def label(input)
      model.label prepare(input)
    end

    def check(input)
      model.check prepare(input, tagged: true)
    end

    def train(input = training_data, truncate: true)
      load_model(nil) if truncate

      unless input.nil? || input.empty?
        model.train prepare(input, tagged: true)
      end

      model
    end

    def learn(input)
      train(input, truncate: false)
    end

    def normalize(item)
      normalizers.each do |n|
        begin
          item = n.normalize(item) unless n.skip?
        rescue => e
          warn "Error in #{n.name} normalizer: #{e.message}"
        end
      end

      item
    end

    def expand(dataset)
      raise NotImplementedError
    end

    def prepare(input, **opts)
      case input
      when Wapiti::Dataset
        expand input
      when Wapiti::Sequence
        expand Wapiti::Dataset.new([input])
      when String
        if !input.tainted? && input.length < 1024 && File.exists?(input)
          expand Wapiti::Dataset.open(input, opts)
        else
          expand Wapiti::Dataset.parse(input, opts)
        end
      else
        expand Wapiti::Dataset.parse(input, opts)
      end
    end

    def training_data
      options[:training_data]
    end
  end


  class Parser < ParserCore
    include Format::BibTeX
    include Format::CSL

    @formats = [:bibtex, :citeproc, :csl, :hash, :wapiti]

    @defaults = {
      model: File.join(SUPPORT, 'parser.mod'),
      pattern: File.join(SUPPORT, 'parser.txt'),
      compact: true,
      threads: 4,
      separator: /(?:\r?\n)+/,
      delimiter: /\s+/,
      format: :hash,
      training_data: File.join(RES, 'parser', 'core.xml')
    }

    def initialize(options = {})
      super(options)

      @features = [
        Feature::Canonical.new,
        Feature::Category.new,
        Feature::Affix.new(size: 2),
        Feature::Affix.new(size: 2, suffix: true),
        Feature::Caps.new,
        Feature::Number.new,
        Feature::Dictionary.new(options[:dictionary]),
        Feature::Keyword.new,
        Feature::Position.new,
        Feature::Punctuation.new,
        Feature::Brackets.new,
        Feature::Terminal.new,
        Feature::Locator.new
      ]

      @normalizers = [
        Normalizer::Quotes.new,
        Normalizer::Punctuation.new,
        Normalizer::Container.new,
        Normalizer::Page.new,
        Normalizer::Date.new,
        Normalizer::Volume.new,
        Normalizer::Location.new,
        Normalizer::Locator.new,
        Normalizer::Publisher.new,
        Normalizer::PubMed.new,
        Normalizer::Names.new,
        Normalizer::Locale.new,
        Normalizer::Type.new
      ]
    end

    def expand(dataset)
      dataset.each do |seq|
        seq.tokens.each_with_index do |tok, idx|
          alpha = scrub tok.value
          tok.observations = features.map { |f|
            f.observe tok.value, alpha: alpha, idx: idx, seq: seq
          }
        end
      end
    end

    def format_hash(dataset)
      dataset.map { |seq| normalize(seq.to_h(symbolize_keys: true)) }
    end

    def parse(input, format: options[:format])
      case format
      when :wapiti
        label(input)
      when :hash, :bibtex, :citeproc, :csl
        formatter = "format_#{format}".to_sym
        send(formatter, label(input))
      else
        raise ArgumentError, "format not supported: #{format}"
      end
    end

    def prepare(input, **opts)
      opts[:separator] ||= options[:separator]
      opts[:delimiter] ||= options[:delimiter]
      super(input, opts)
    end
  end
end
