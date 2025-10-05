# encoding: UTF-8
module Plugins
  module S2kTools
    DICT = "dynamic_attributes".freeze
    def self.cm(v) v.to_f / 2.54 end   # cm -> inch (belső tárolás)

    # -- Modell egységek: CENTIMETERS --
    def self.set_model_units_to_cm
      m = Sketchup.active_model
      u = m.options["UnitsOptions"]
      u["LengthUnit"]      = 3   # 0=in, 1=ft, 2=mm, 3=cm, 4=m
      u["LengthFormat"]    = 0   # Decimal
      u["LengthPrecision"] = 2
    end

    # -- segéd: ugyanaz a meta a definition-ön és az instance-on --
    def self.set_meta_both(instance, key, value)
      instance.definition.attribute_dictionary(DICT, true)[key] = value
      instance.attribute_dictionary(DICT, true)[key]            = value
    end

    # -- LIST helper (&Label=Value&...) --
    # pairs: [ ['0 Nincs',0], ['1 Alíz',1], ... ]
    def self.add_dc_list(instance, name, pairs, default_value=nil, value_type=:string, display_label=nil)
      opts = pairs.map { |lab,val| "&#{lab}=#{val}&" }.join
      set_meta_both(instance, "_#{name}_access",       "LIST")
      set_meta_both(instance, "_#{name}_label",        name)
      set_meta_both(instance, "_#{name}_formlabel",    (display_label || name))
      set_meta_both(instance, "_#{name}_options",      opts)
      units = (value_type == :float ? "FLOAT" : "STRING")
      set_meta_both(instance, "_#{name}_units",        units)
      set_meta_both(instance, "_#{name}_formulaunits", units)

      default_value = pairs.first && pairs.first[1] if default_value.nil?
      instance.attribute_dictionary(DICT, true)[name] =
        (value_type == :float ? default_value.to_f : default_value.to_s)
    end

    # -- Sima számmező cm-ben (TEXTBOX) --
    def self.add_dc_number_cm(instance, name, value_cm, display_label=nil)
      set_meta_both(instance, "_#{name}_label",        name)
      set_meta_both(instance, "_#{name}_formlabel",    (display_label || name))
      set_meta_both(instance, "_#{name}_units",        "CENTIMETERS")
      set_meta_both(instance, "_#{name}_displayunits", "CENTIMETERS")
      set_meta_both(instance, "_#{name}_access",       "TEXTBOX")
      set_meta_both(instance, "_#{name}_formulaunits", "CENTIMETERS")
      instance.attribute_dictionary(DICT, true)[name] = cm(value_cm) # érték inch-ben
    end

    # -- Képletes számmező (FORMULA) cm-ben --
    # formula_without_equals: ne tegyél elé '='-t (a DC UI hozzáadja)
    # show_in_options: false -> teljesen rejtve a Component Options-ban
    def self.add_dc_formula_cm(instance, name, formula_without_equals, display_label=nil, show_in_options: false)
      set_meta_both(instance, "_#{name}_label",         name)
      set_meta_both(instance, "_#{name}_units",         "CENTIMETERS")
      set_meta_both(instance, "_#{name}_displayunits",  "CENTIMETERS")
      set_meta_both(instance, "_#{name}_formula",       formula_without_equals.to_s.strip)
      set_meta_both(instance, "_#{name}_formulaunits",  "CENTIMETERS")

      if show_in_options
        set_meta_both(instance, "_#{name}_access", "FORMULA")
        set_meta_both(instance, "_#{name}_formlabel", (display_label || name))
      else
        set_meta_both(instance, "_#{name}_access", "NONE")
        [instance.definition.attribute_dictionary(DICT, true),
         instance.attribute_dictionary(DICT, true)].each { |ad| ad.delete_key("_#{name}_formlabel") rescue nil }
      end

      instance.attribute_dictionary(DICT, true)[name] = 0.0
    end

    # -- Material attribútum képlettel (STRING) --
    # formula_without_equals pl.: 'handle_material' vagy 'Parent!handle_material'
    def self.add_dc_material_formula(instance, formula_without_equals, show_in_options: false, display_label: nil)
      set_meta_both(instance, "_material_label",        "material")
      set_meta_both(instance, "_material_units",        "STRING")
      set_meta_both(instance, "_material_displayunits", "STRING")
      set_meta_both(instance, "_material_formula",      formula_without_equals.to_s.strip)

      if show_in_options
        set_meta_both(instance, "_material_access", "FORMULA")
        set_meta_both(instance, "_material_formlabel", (display_label || "Material"))
      else
        set_meta_both(instance, "_material_access", "NONE")
        [instance.definition.attribute_dictionary(DICT, true),
         instance.attribute_dictionary(DICT, true)].each { |ad| ad.delete_key("_material_formlabel") rescue nil }
      end

      instance.attribute_dictionary(DICT, true)["material"] = ""
    end

    # ----------------------- MÉRET/IRÁNY MÁSOLÁS -----------------------------

    # Stabil kiválasztási sorrend: első = CÉL, utolsó = FORRÁS
    @sel_order ||= []
    def self.sel_added(ent)
      return unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
      @sel_order.delete(ent)
      @sel_order << ent
    end
    def self.reset_sel_order
      @sel_order = []
    end

    class SelObs < Sketchup::SelectionObserver
      def onSelectionAdded(selection, entity)
        Plugins::S2kTools.sel_added(entity)
      end
      def onSelectionCleared(selection)
        Plugins::S2kTools.reset_sel_order
      end
    end

    def self.ensure_selection_observer
      return if @sel_obs_attached
      Sketchup.active_model.selection.add_observer(SelObs.new)
      @sel_obs_attached = true
    end

    # Lokális (entitás-tengely) méret számítása
    def self.local_size(ent)
      t_inv = ent.transformation.inverse
      bb    = ent.bounds
      # 8 sarok lokális térben
      pts = []
      corners = [
        Geom::Point3d.new(bb.min.x, bb.min.y, bb.min.z),
        Geom::Point3d.new(bb.min.x, bb.min.y, bb.max.z),
        Geom::Point3d.new(bb.min.x, bb.max.y, bb.min.z),
        Geom::Point3d.new(bb.min.x, bb.max.y, bb.max.z),
        Geom::Point3d.new(bb.max.x, bb.min.y, bb.min.z),
        Geom::Point3d.new(bb.max.x, bb.min.y, bb.max.z),
        Geom::Point3d.new(bb.max.x, bb.max.y, bb.min.z),
        Geom::Point3d.new(bb.max.x, bb.max.y, bb.max.z)
      ]
      corners.each { |p| pts << p.transform(t_inv) }
      xs = pts.map(&:x); ys = pts.map(&:y); zs = pts.map(&:z)
      [xs.max - xs.min, ys.max - ys.min, zs.max - zs.min]
    end

    # Orientáció egyeztesítése: a CÉL helye marad, tengelyei a FORRÁSÉ lesznek
    def self.align_orientation!(target, source)
      to = target.transformation.origin
      tx = source.transformation.xaxis
      ty = source.transformation.yaxis
      tz = source.transformation.zaxis
      target.transformation = Geom::Transformation.axes(to, tx, ty, tz)
    end

    # Lokális skálázás ismételhetően (T * S * T^-1)
    def self.scale_to_local_size!(target, dst_x, dst_y, dst_z)
      cur_x, cur_y, cur_z = local_size(target)
      sx = (cur_x.abs < 1e-9) ? 1.0 : (dst_x / cur_x)
      sy = (cur_y.abs < 1e-9) ? 1.0 : (dst_y / cur_y)
      sz = (cur_z.abs < 1e-9) ? 1.0 : (dst_z / cur_z)
      t  = target.transformation
      s  = Geom::Transformation.scaling(ORIGIN, sx, sy, sz)
      tr = t * s * t.inverse
      target.transform!(tr)
    end

    # Parancs: az első kijelölt = CÉL, az utolsó = FORRÁS
    def self.set_attribute_sub
      m = Sketchup.active_model
      ensure_selection_observer

      usable = @sel_order.select { |e|
        m.selection.include?(e) && (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance))
      }
      if usable.length < 2
        UI.messagebox("Kijelölés sorrendje számít:\n1) jelöld a CÉLT, 2) SHIFT+klikk a FORRÁSRA, majd futtasd a parancsot.")
        return
      end

      target = usable.first
      source = usable.last

      sx, sy, sz = local_size(source)

      m.start_operation("Második mérete/irány → elsőre", true)
      align_orientation!(target, source)
      scale_to_local_size!(target, sx, sy, sz)
      m.commit_operation
    end

    # ----------------------- DC DEMÓ (maradt, ahogy kértél) -------------------

    def self.set_attribute_main
      m = Sketchup.active_model
      inst = m.selection.first
      unless inst.is_a?(Sketchup::ComponentInstance)
        UI.messagebox("Válassz ki egy komponenst.")
        return
      end

      m.start_operation("Set DC attrs (cm)", true)
      set_model_units_to_cm

      add_dc_list(inst, "direction", [['Bal',0], ['Jobb',1]], 0, :float, "Nyitási irány")

      front_pairs = [
        ['0 Nincs',0], ['1 Alíz',1], ['2 Anikó/Dorina',2],
        ['3 Flóra',3], ['4 Gréta',4], ['5 Helga',5], ['6 Orsi',6]
      ]
      add_dc_list(inst, "front_type", front_pairs, 0, :float, "Front típus")

      handle_pairs = [
        ['0 Nincs',0], ['180 cm',1], ['135 cm',2], ['130 cm',3]
      ]
      add_dc_list(inst, "handle", handle_pairs, 0, :float, "Fogantyú típus")

      handle_material_pairs = [
        ['0 Nincs',''],
        ['Piros','Red'], ['Zöld','Green'], ['Kék','Blue']
      ]
      add_dc_list(inst, "handle_material", handle_material_pairs, '', :string, "Textúra")

      add_dc_number_cm(inst, "front_thickness", 50.0, "Bútorlap vastagság")

      # Material a listából (rejtve az Options-ban)
      add_dc_material_formula(inst, 'handle_material', show_in_options: false)

      # Képlet cm-ben, rejtve az Options-ból
      add_dc_formula_cm(
        inst,
        "handleoffset",
        'CHOOSE(OPTIONINDEX("front_type"), 0, 26.5, 25, 26.5, 25.35, 23.75, 26.5)',
        "Fogantyú eltolás",
        show_in_options: false
      )

      m.commit_operation
      # Megjegyzés: ha a Component Options már nyitva volt, zárd-nyisd újra a frissítéshez.
    end

    # biztosítsuk, hogy a figyelő aktív legyen
    ensure_selection_observer if defined?(Sketchup)
  end
end
