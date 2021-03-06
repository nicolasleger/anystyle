module AnyStyle
  class Normalizer
    class Type < Normalizer
      def normalize(item)
        item[:type] = classify item
        item
      end

      def classify(item)
        keys = item.keys

        case
        when keys.include?(:journal)
          'article'
        when keys.include?(:'container-title')
          case item[:'container-title'].to_s
          when /proceedings|proc\.|conference|meeting|symposi(on|um)/i
            'paper-conference'
          else
            'chapter'
          end
        when keys.include?(:genre)
          case item[:genre].to_s
          when /ph(\.\s*)?d|diss(\.|ertation)|thesis/i
            'thesis'
          when /rep(\.|ort)/i
            'report'
          when /unpublished|manuscript/i
            'manuscript'
          when /patent/i
            'patent'
          when /personal communication/i
            'personal_communication'
          when /interview/i
            'interview'
          when /web|online|en ligne/
            'webpage'
          end
        when keys.include?(:medium)
          case item[:medium].to_s
          when /dvd|video|vhs|motion/i
            'motion_picture'
          when /television/i
            'broadcast'
          end
        when keys.include?(:publisher)
          'book'
        end
      end
    end
  end
end
