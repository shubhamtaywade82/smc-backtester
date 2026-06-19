# frozen_string_literal: true

require_relative 'pb_definitions/pb01'
require_relative 'pb_definitions/pb02'
require_relative 'pb_definitions/pb03'
require_relative 'pb_definitions/pb04'
require_relative 'pb_definitions/pb05'
require_relative 'pb_definitions/pb06'
require_relative 'pb_definitions/pb07'
require_relative 'pb_definitions/pb08'

require_relative 'pb_definitions/pb_c'
require_relative 'pb_definitions/pb_d'
require_relative 'pb_definitions/pb_e'
require_relative 'pb_definitions/pb_f'
require_relative 'pb_definitions/pb_g'
require_relative 'pb_definitions/pb_h'
require_relative 'pb_definitions/pb_mtf'

module SMC
  module Playbook
    module PbDefinitions
      ALL_IDS = %w[
        PB-1 PB-2 PB-3 PB-4 PB-5 PB-6 PB-7 PB-8
        PB-C PB-D PB-E PB-F PB-G PB-H PB-MTF
      ].freeze

      def self.register_all(registry: PlaybookRegistry.default)
        ALL_IDS.each do |id|
          playbook = case id
                     when 'PB-1' then pb01
                     when 'PB-2' then pb02
                     when 'PB-3' then pb03
                     when 'PB-4' then pb04
                     when 'PB-5' then pb05
                     when 'PB-6' then pb06
                     when 'PB-7' then pb07
                     when 'PB-8' then pb08
                     when 'PB-C' then pb_c
                     when 'PB-D' then pb_d
                     when 'PB-E' then pb_e
                     when 'PB-F' then pb_f
                     when 'PB-G' then pb_g
                     when 'PB-H' then pb_h
                     when 'PB-MTF' then pb_mtf
                     end
          registry.register(playbook) if playbook
        end
        registry
      end
    end
  end
end

# Auto-register all playbook definitions into the default registry
# when this file is loaded.
SMC::Playbook::PbDefinitions.register_all
