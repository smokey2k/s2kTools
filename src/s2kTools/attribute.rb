# encoding: UTF-8
require 'sketchup.rb'

module Plugins
  module S2kTools
    # --------------------------- ÁLTALÁNOS ---------------------------
    DICT = 'dynamic_attributes'.freeze

    def self.cm(v) v.to_f / 2.54 end   # cm -> inch (belső SU)

    def self.set_model_units_to_cm
      m = Sketchup.active_model
      u = m.options['UnitsOptions']
      u['LengthUnit']      = 3   # 0=in,1=ft,2=mm,3=cm,4=m
      u['LengthFormat']    = 0   # Decimal
      u['LengthPrecision'] = 2
    end

    def self.set_meta_both(instance, key, value)
      instance.definition.attribute_dictionary(DICT, true)[key] = value
      instance.attribute_dictionary(DICT, true)[key]            = value
    end

    # ----------------------- DC HELPEREK -----------------------------

    # LIST: pairs = [ ['Felirat', val], ... ]
    def self.add_dc_list(instance, name, pairs, default_value=nil, value_type=:string, display_label=nil)
      opts = pairs.map { |lab,val| "&#{lab}=#{val}&" }.join
      set_meta_both(instance, "_#{name}_access",       'LIST')
      set_meta_both(instance, "_#{name}_label",        name)
      set_meta_both(instance, "_#{name}_formlabel",    (display_label || name))
      set_meta_both(instance, "_#{name}_options",      opts)
      units = (value_type == :float ? 'FLOAT' : 'STRING')
      set_meta_both(instance, "_#{name}_units",        units)
      set_meta_both(instance, "_#{name}_formulaunits", units)

      default_value = pairs.first && pairs.first[1] if default_value.nil?
      instance.attribute_dictionary(DICT, true)[name] =
        (value_type == :float ? default_value.to_f : default_value.to_s)
    end

    # Számmező cm-ben (TEXTBOX)
    def self.add_dc_number_cm(instance, name, value_cm, display_label=nil)
      set_meta_both(instance, "_#{name}_label",        name)
      set_meta_both(instance, "_#{name}_formlabel",    (display_label || name))
      set_meta_both(instance, "_#{name}_units",        'CENTIMETERS')
      set_meta_both(instance, "_#{name}_displayunits", 'CENTIMETERS')
      set_meta_both(instance, "_#{name}_access",       'TEXTBOX')
      set_meta_both(instance, "_#{name}_formulaunits", 'CENTIMETERS')
      instance.attribute_dictionary(DICT, true)[name] = cm(value_cm) # érték inch-ben
    end

    # Képletes számmező cm-ben – NINCS '=' a képlet elején
    def self.add_dc_formula_cm(instance, name, formula_without_equals, display_label=nil, show_in_options: false)
      set_meta_both(instance, "_#{name}_label",         name)
      set_meta_both(instance, "_#{name}_units",         'CENTIMETERS')
      set_meta_both(instance, "_#{name}_displayunits",  'CENTIMETERS')
      set_meta_both(instance, "_#{name}_formula",       formula_without_equals.to_s.strip)
      set_meta_both(instance, "_#{name}_formulaunits",  'CENTIMETERS')
      if show_in_options
        set_meta_both(instance, "_#{name}_access", 'FORMULA')
        set_meta_both(instance, "_#{name}_formlabel", (display_label || name))
      else
        set_meta_both(instance, "_#{name}_access", 'NONE')
        [instance.definition.attribute_dictionary(DICT, true),
         instance.attribute_dictionary(DICT, true)].each { |ad| ad.delete_key("_#{name}_formlabel") rescue nil }
      end
      instance.attribute_dictionary(DICT, true)[name] = 0.0
    end

    # Material képlet (STRING)
    def self.add_dc_material_formula(instance, formula_without_equals, show_in_options: false, display_label: nil)
      set_meta_both(instance, '_material_label',        'material')
      set_meta_both(instance, '_material_units',        'STRING')
      set_meta_both(instance, '_material_displayunits', 'STRING')
      set_meta_both(instance, '_material_formula',      formula_without_equals.to_s.strip)
      if show_in_options
        set_meta_both(instance, '_material_access', 'FORMULA')
        set_meta_both(instance, '_material_formlabel', (display_label || 'Material'))
      else
        set_meta_both(instance, '_material_access', 'NONE')
        [instance.definition.attribute_dictionary(DICT, true),
         instance.attribute_dictionary(DICT, true)].each { |ad| ad.delete_key('_material_formlabel') rescue nil }
      end
      instance.attribute_dictionary(DICT, true)['material'] = ''
    end

    # ---------------- DEMÓ ATTRIBÚTUM FELÍRÁS ----------------------

    def self.set_attribute_main
      m = Sketchup.active_model
      inst = m.selection.first
      unless inst.is_a?(Sketchup::ComponentInstance)
        UI.messagebox('Válassz ki egy komponenst.')
        return
      end

      m.start_operation('Set DC attrs (cm)', true)
      set_model_units_to_cm

      add_dc_list(inst, 'direction', [['Bal',0], ['Jobb',1]], 0, :float, 'Nyitási irány')

      front_pairs = [
        ['0 Nincs',0], ['1 Alíz',1], ['2 Anikó/Dorina',2],
        ['3 Flóra',3], ['4 Gréta',4], ['5 Helga',5], ['6 Orsi',6]
      ]
      add_dc_list(inst, 'front_type', front_pairs, 0, :float, 'Front típus')

      handle_pairs = [
        ['0 Nincs',0], ['180 cm',1], ['135 cm',2], ['130 cm',3]
      ]
      add_dc_list(inst, 'handle', handle_pairs, 0, :float, 'Fogantyú típus')

      handle_material_pairs = [
        ['0 Nincs',''], ['Piros','Red'], ['Zöld','Green'], ['Kék','Blue']
      ]
      add_dc_list(inst, 'handle_material', handle_material_pairs, '', :string, 'Textúra')

      add_dc_number_cm(inst, 'front_thickness', 50.0, 'Bútorlap vastagság')

      add_dc_material_formula(inst, 'handle_material', show_in_options: false)

      add_dc_formula_cm(
        inst,
        'handleoffset',
        'CHOOSE(OPTIONINDEX("front_type"), 0, 26.5, 25, 26.5, 25.35, 23.75, 26.5)',
        'Fogantyú eltolás',
        show_in_options: false
      )

      m.commit_operation
    end

    # =================================================================
    # ==================  MATCH SIZE – DC-BARÁT TOOL  =================
    # =================================================================

    # --- DC detektálás ---
    def self.dc_dict(ent) ent.attribute_dictionary(DICT, false) end

    def self.dc_buildable?(ent)
      ad = dc_dict(ent)
      ad && ad['Class'].to_s.strip.downcase == 'buildable'
    end

    def self.dc_has_len?(ent)
      ad = dc_dict(ent)
      ad && ad.key?('LenX') && ad.key?('LenY') && ad.key?('LenZ')
    end

    # --- DC redraw biztosan ---
    def self.dc_redraw!(inst)
      if defined?($dc_observers) && $dc_observers.respond_to?(:get_latest_class)
        $dc_observers.get_latest_class.redraw_with_undo(
          Sketchup.active_model.active_entities, [inst]
        )
        return
      end
      m   = Sketchup.active_model
      sel = m.selection.to_a
      begin
        m.selection.clear
        m.selection.add(inst)
        Sketchup.send_action('dynamiccomponents:redraw')
      ensure
        m.selection.clear
        sel.each { |e| m.selection.add(e) }
      end
    end

    # Forrás méret lekérdezése (inch)
    def self.source_size_in(ent)
      if dc_buildable?(ent) && dc_has_len?(ent)
        ad = dc_dict(ent)
        [ad['LenX'].to_f, ad['LenY'].to_f, ad['LenZ'].to_f]
      else
        bb = ent.bounds
        v  = bb.max - bb.min
        [v.x.to_f, v.y.to_f, v.z.to_f]
      end
    end

    # Tájolás egyeztetése CSAK ha egyik sem DC-buildable
    def self.reorient_like_if_safe!(target, source)
      return if dc_buildable?(target) || dc_buildable?(source)
      pos  = target.transformation.origin
      tsrc = source.transformation
      taxis = Geom::Transformation.axes(pos, tsrc.xaxis, tsrc.yaxis, tsrc.zaxis)
      target.transform!(target.transformation.inverse * taxis)
    end

    # Cél beállítása: DC-nél origó vissza, egyébként skálázás
    def self.apply_size_to_target!(target, want_x, want_y, want_z)
      want_x = want_x.to_f
      want_y = want_y.to_f
      want_z = want_z.to_f

      if dc_buildable?(target) && dc_has_len?(target)
        before = target.transformation.origin

        ad = target.attribute_dictionary(DICT, true)
        ad['LenX'] = want_x
        ad['LenY'] = want_y
        ad['LenZ'] = want_z
        ad['_hasbehaviors'] = 1.0
        target.set_attribute(DICT, '_lastmodified', Time.now.to_f)

        begin
          dc_redraw!(target)
        rescue
        end

        after = target.transformation.origin
        delta = before - after
        unless delta == Geom::Vector3d.new(0,0,0)
          target.transform!(Geom::Transformation.translation(delta))
        end
      else
        cur_x, cur_y, cur_z = source_size_in(target)
        sx = cur_x.zero? ? 1.0 : (want_x / cur_x)
        sy = cur_y.zero? ? 1.0 : (want_y / cur_y)
        sz = cur_z.zero? ? 1.0 : (want_z / cur_z)
        pivot = target.bounds.min
        target.transform!(Geom::Transformation.scaling(pivot, sx, sy, sz))
      end
    end

    # ------------------ TOOL (két kattintás) -------------------------
    class MatchSizeTool
      def activate
        @state  = :pick_target
        @target = @source = nil
        Sketchup.status_text = "Match Size: kattints a CÉL elemre (Group/Component)."
      end

      def deactivate(view)
        Sketchup.status_text = ""
      end

      def onLButtonDown(flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        ent = ph.best_picked
        ent = ent.parent if ent.is_a?(Sketchup::ComponentDefinition)

        unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
          UI.beep
          return
        end

        case @state
        when :pick_target
          @target = ent
          @state  = :pick_source
          Sketchup.status_text = "Match Size: most kattints a FORRÁS elemre."
        when :pick_source
          if ent == @target
            UI.messagebox("A forrás nem lehet ugyanaz, mint a cél.")
            reset
            return
          end
          @source = ent
          perform(view)
          view.model.tools.pop_tool # egy lövés
        end
      end

      def perform(view)
        m = view.model
        m.start_operation("Match Size (forrás → cél)", true)
        sx, sy, sz = Plugins::S2kTools.source_size_in(@source)
        Plugins::S2kTools.reorient_like_if_safe!(@target, @source)
        Plugins::S2kTools.apply_size_to_target!(@target, sx, sy, sz)
        m.commit_operation
      end

      def reset
        @state = :pick_target
        @target = @source = nil
        Sketchup.status_text = "Match Size: kattints a CÉL elemre."
      end
    end

    # Toolbarból hívd:
    def self.start_match_size_tool
      Sketchup.active_model.tools.push_tool(MatchSizeTool.new)
    end
  end
end
