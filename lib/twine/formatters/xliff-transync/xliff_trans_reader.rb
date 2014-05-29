### This module comes from [transync](https://github.com/zigomir/transync) 

require 'nokogiri'

class XliffTransReader
  
  attr_accessor :path
  attr_accessor :file
  attr_accessor :languages
  attr_accessor :dev_language
  
  def initialize(path, file, languages, dev_language)
    @path = path
    @file = file
    @languages = languages
    if dev_language
      @dev_language = dev_language
    else
      @dev_language = 'en'
    end
  end

  def translations(language)
    data = { file: @file, language: language, translations: {}, notes: {}, sections: {} }

    open_file(language) do |doc|
      doc.remove_namespaces!
      groups = doc.xpath('//group')
      if groups and groups.length > 0
        groups.each do |group|
          group_id = ''
          if group.id
            group_id = group.id
          end
          section = { name: group_id, translations: {}, notes: {}}
          
          group.xpath('//trans-unit').each do |node|
            key = node.xpath('source').text.gsub(/\n/,'\\n')
            value = node.xpath('target').text.gsub(/\n/,'\\n')
            note = node.xpath('note').text.gsub(/\n/,'\\n')

            data[:translations][key] = value        
            data[:notes][key] = note
            
            section[:translations][key] = value
            section[:notes][key] = note
          end
          
          data[:sections][group_id] = section
        end
      else
        doc.xpath('//trans-unit').each do |node|
          key = node.xpath('source').text.gsub(/\n/,'\\n')
          value = node.xpath('target').text.gsub(/\n/,'\\n')
          note = node.xpath('note').text.gsub(/\n/,'\\n')
          data[:translations][key] = value
          data[:notes][key] = note
        end
      end
    end

    data
  end

  def valid?
    missing = 0

    check_all do |lang_a, lang_b, xliff_lang_value, xliff_note, x_trans_key|
      if xliff_lang_value.nil?
        p "Comparing #{@file}.#{lang_a} against #{@file}.#{lang_b} => #{@file}.#{lang_b} "\
          "is missing translation for key '#{x_trans_key}'"
        missing += 1
      end
    end

    missing == 0
  end

  def fill_with_missing_keys
    missing_translation_text = '#MISSING-TRANSLATION#'
    all_translations_for_language = {file: @file, language: nil, translations: {}, notes: {}}
    added = false
    clean = true

    check_all do |lang_a, lang_b, xliff_lang_value, xliff_note, x_trans_key, translations_lang_b, notes_lang_b, last| # x_trans_key comes from lang_a translations
      all_translations_for_language[:language] = lang_b

      if xliff_lang_value.nil?
        p "Comparing #{@file}.#{lang_a} against #{@file}.#{lang_b} => #{@file}.#{lang_b} "\
          "was missing translation for key '#{x_trans_key}' => setting value: '#{missing_translation_text} - #{x_trans_key}'"
        all_translations_for_language[:translations][x_trans_key] = "#{missing_translation_text} - #{x_trans_key}"
        added = true
        clean = false
      else
        all_translations_for_language[:translations][x_trans_key] = xliff_lang_value
        all_translations_for_language[:notes][x_trans_key] = xliff_note
      end

      if last
        if added
          all_translations_for_language[:translations] = translations_lang_b.merge(all_translations_for_language[:translations])
          all_translations_for_language[:notes] = notes_lang_b.merge(all_translations_for_language[:notes])
          xliff_trans_writer = XliffTransWriter.new(@path, @file, @dev_language)
          xliff_trans_writer.write(all_translations_for_language)
        end

        # clear
        all_translations_for_language[:translations] = {}
        all_translations_for_language[:notes] = {}
        added = false
      end
    end

    # return if any key was added
    clean
  end

  def check_all
    @languages.each do |lang_a|
      @languages.each do |lang_b|
        next if lang_a == lang_b

        xliff_reader = XliffTransReader.new(@path, @file, @languages, @dev_language)
        translations_lang_a = self.translations(lang_a)[:translations]
        notes_lang_a = self.translations(lang_a)[:notes]
        keys = translations_lang_a.keys
        i = 1

        keys.each do |x_trans_key|
          translations_lang_b = xliff_reader.translations(lang_b)[:translations]
          notes_lang_b = xliff_reader.translations(lang_b)[:notes]
          xliff_lang_value = translations_lang_b[x_trans_key]
          xliff_note = notes_lang_b[x_trans_key]
          yield(lang_a, lang_b, xliff_lang_value, xliff_note, x_trans_key, translations_lang_b, notes_lang_b, keys.length == i) # last key?
          i += 1
        end
      end
    end
  end

  # Reading from source tags in xliff
  def open_file(language)
    begin
      xml_file = File.open(file_path(language))
      doc = Nokogiri::XML(xml_file)
      yield doc
    rescue Errno::ENOENT => e
      abort(e.message)
    end
  end

private

  def file_path(language)
    temp_lang = language.gsub('-', '_')
    "#{@path}/#{@file}_#{temp_lang}.xlf"
  end

end
