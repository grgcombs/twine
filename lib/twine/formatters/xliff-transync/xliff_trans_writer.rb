### This module comes from [transync](https://github.com/zigomir/transync) 

require 'builder'

class XliffTransWriter

  attr_accessor :path
  attr_accessor :file
  attr_accessor :dev_language

  def initialize(path, file, dev_language)
    @path = path
    @file = file
    if dev_language
      @dev_language = dev_language
    else
      @dev_language = 'en'
    end
  end

  def write(trans_hash)
    language     = trans_hash[:language].gsub('_', '-')
    translations = trans_hash[:translations]
    notes        = trans_hash[:notes]
    sections     = trans_hash[:sections]

    xml = Builder::XmlMarkup.new( :indent => 4 )
    xml.instruct! :xml, :encoding => 'UTF-8'
    xml.xliff :version => '1.2', :xmlns => 'urn:oasis:names:tc:xliff:document:1.2' do |xliff|
      xliff.file :'source-language' => @dev_language, :'target-language' => language, :datatype => 'plaintext', :original => 'file.ext' do |xliff_file|
        xliff_file.body do |body|

          if sections and sections.length > 0
            
            sections.keys.each do |section_id|
              section = sections[section_id]
              section_trans = section[:translations]
              section_notes = section[:notes]
              section_keys = section_trans.keys
              
              body.tag! 'group', :id => section_id do |trans_group|
                section_keys.each do |trans_key|
                  clean_key = trans_key.gsub('\\n','\n')
                  trans_group.tag! 'trans-unit', :id => clean_key do |trans_unit|
                    trans_unit.source clean_key
                    trans_unit.target section_trans[trans_key].gsub('\\n','\n')
                    if section_notes[trans_key]
                      trans_unit.note section_notes[trans_key].gsub('\\n','\n')
                    end
                  end
                end
                
              end              
            end
          else
            translations.keys.each do |trans_key|
              body.tag! 'trans-unit', :id => trans_key do |trans_unit|
                trans_unit.source trans_key.gsub('\\n','\n')
                trans_unit.target translations[trans_key].gsub('\\n','\n')
                if notes[trans_key]
                  trans_unit.note notes[trans_key].gsub('\\n','\n')
                end
              end
            end
          end
        end
      end
    end

    File.open(file_path(language), 'w') { |xliff_file| xliff_file.write(xml.target!) }
  end

private

  def file_path(language)
    temp_lang = language.gsub('-', '_')
    "#{@path}/#{@file}_#{temp_lang}.xlf"
  end

end
