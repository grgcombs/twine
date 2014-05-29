# encoding: utf-8

require 'twine/formatters/xliff-transync/xliff_trans_reader'
require 'twine/formatters/xliff-transync/xliff_trans_writer'

module Twine
  module Formatters
    class XLIFF < Abstract
      FORMAT_NAME = 'xliff'
      EXTENSION = '.xlf'
      DEFAULT_FILE_NAME = 'strings.xlf'
      LANG_CODES = Hash[
        'zh' => 'zh-Hans',
        'zh-rCN' => 'zh-Hans',
        'zh-rHK' => 'zh-Hant',
        'en-rGB' => 'en-UK',
        'in' => 'id',
        'nb' => 'no'
        # TODO: spanish
      ]
      DEFAULT_LANG_CODES = Hash[
        'zh-TW' => 'zh-Hant' # if we don't have a zh-TW translation, try zh-Hant before en
      ]

      def self.can_handle_directory?(path)
        Dir.entries(path).any? { |item| /^.+\.(xlf|xliff)$/.match(item) }
      end

      def default_file_name
        return DEFAULT_FILE_NAME
      end

      def determine_language_given_path(path)
        path_arr = path.split(File::SEPARATOR)
        path_arr.each do |segment|
          match = /^.+_([a-z][a-z]_?-?[A-Z]?[A-Z]?)\.(xlf|xliff)$/.match(segment)
          if match
            lang = match[1].gsub('_','-')
            lang = LANG_CODES.fetch(lang, lang)
            lang.sub!('-r', '-')
            return lang
          end
        end

        return @strings.language_codes[0]
      end
      
      def determine_shortname_given_fullname(fullname)
        match = /^(.+)_([a-z][a-z]_?-?[A-Z]?[A-Z]?)\.(xlf|xliff)$/.match(fullname)
        if match
          file = match[1]
          return file
        end

        return
      end
      

      def read_file(path, lang)
        components = File.split(path)
        path_component = components[0]
        filename = self.determine_shortname_given_fullname(components[1])
        lang.gsub!('_', '-')
        xliff_reader = XliffTransReader.new(path_component, filename, [lang], @options[:developer_language])
        
        data = xliff_reader.translations(lang)
        translations = data[:translations]
        keys = translations.keys
        notes = data[:notes]
        sections = data[:sections]
        
        key = nil
        value = nil
        comment = nil
        
        keys.each do |key|
          clean_key = key.sub(/^\[/,'~~[~~')
          value = translations[key]
          value = CGI.unescapeHTML(value)
          value.gsub!('\\\'', '\'')
          value.gsub!('\\"', '"')
          value = iosify_substitutions(value)
          value.gsub!(/(\\u0020)*|(\\u0020)*\z/) { |spaces| ' ' * (spaces.length / 6) }

          comment = notes[key]

          set_translation_for_key(clean_key, lang, value)
          value = nil
          
          if @options[:consume_comments] and comment and comment.length > 0
            set_comment_for_key(key, comment)
          end
          comment = nil
        end
      end

      def write_file(path, lang)
        lang.gsub!('_', '-')

        default_lang = nil
        if DEFAULT_LANG_CODES.has_key?(lang)
          default_lang = DEFAULT_LANG_CODES[lang]
        end
        
        components = File.split(path)
        path_component = components[0]
        filename = self.determine_shortname_given_fullname(components[1])
        xliff_writer = XliffTransWriter.new(path_component, filename, @options[:developer_language])
        
        output = { language: lang, translations: {}, notes: {}, sections: {}}
        
        @strings.sections.each do |section|
          
          section_name = 'Uncategorized'
          if section.name and section.name.length > 0
            section_name = section.name
          end
          
          section_output = { name: section_name, translations: {}, notes: {}}
          trans_count = 0
          
          section.rows.each do |row|
            
            if row.matches_tags?(@options[:tags], @options[:untagged])
                            
              key = row.key
              key = key.gsub('"', '\\\\"')
              value = row.translated_string_for_lang(lang, default_lang)
              if !value && @options[:include_untranslated]
                value = row.translated_string_for_lang(@strings.language_codes[0])
              end
              
              if value
                trans_count = trans_count + 1
                value = value.gsub('"', '\\\\"')
                
                swapped_key = key.gsub('~~[~~','[')
                section_output[:translations][swapped_key] = value
                output[:translations][swapped_key] = value
        
                comment = row.comment
                if comment and comment.length > 0
                  section_output[:notes][swapped_key] = comment
                  output[:notes][swapped_key] = comment
                end
              end
            end      
          end
          
          if trans_count > 0
            output[:sections][section_name] = section_output
          end
          
        end
        
        xliff_writer.write(output)
        
      end
    end
  end
end
