# encoding: UTF-8
module Plugins
  module S2kTools
    DICT = "dynamic_attributes".freeze
    def self.cm(v) v.to_f / 2.54 end   # cm -> inch (belso tarolas)

    # -- Modell egységek: CENTIMETERS --
    def self.set_model_units_to_cm
      m = Sketchup.active_model
      u = m.options["UnitsOptions"]
      u["LengthUnit"]      = 3   # 0=in, 1=ft, 2=mm, 3=cm, 4=m
      u["LengthFormat"]    = 0   # Decimal
      u["LengthPrecision"] = 2
    end

    # --- segéd: meta kulcsot írj definition-RE is és instance-RA is
    def self.set_meta_both(instance, key, value)
      instance.definition.attribute_dictionary(DICT, true)[key] = value
      instance.attribute_dictionary(DICT, true)[key]            = value
    end

    # -- LIST helper (&Label=Value&...) --
    def self.add_dc_list(instance, name, pairs, default_value=nil, value_type=:string, display_label=nil)
      opts = pairs.map { |lab,val| "&#{lab}=#{val}&" }.join

      # meta (duplán írva)
      set_meta_both(instance, "_#{name}_access",       "LIST")
      set_meta_both(instance, "_#{name}_label",        name)                         # Attributes panelen ez lesz a mező neve
      set_meta_both(instance, "_#{name}_formlabel",    (display_label || name))      # Options párbeszéd felirata
      set_meta_both(instance, "_#{name}_options",      opts)
      units = (value_type == :float ? "FLOAT" : "STRING")
      set_meta_both(instance, "_#{name}_units",        units)
      set_meta_both(instance, "_#{name}_formulaunits", units)

      # érték
      default_value = pairs.first && pairs.first[1] if default_value.nil?
      instance.attribute_dictionary(DICT, true)[name] =
        (value_type == :float ? default_value.to_f : default_value.to_s)
    end

    
    # -- Képletes számmező cm-ben (FORMULA) --
    # FIGYELEM: NINCS '=' a formula elején – a DC UI teszi hozzá; így elkerülöd a dupla '='-t.
    def self.add_dc_formula_cm(instance, name, formula_without_equals, display_label=nil, show_in_options: false)
      set_meta_both(instance, "_#{name}_label",         name)
      set_meta_both(instance, "_#{name}_units",         "CENTIMETERS")
      set_meta_both(instance, "_#{name}_displayunits",  "CENTIMETERS")
      set_meta_both(instance, "_#{name}_access",        "FORMULA")
      set_meta_both(instance, "_#{name}_formula",       formula_without_equals.to_s.strip) # nincs '='
      set_meta_both(instance, "_#{name}_formulaunits",  "CENTIMETERS")
    
      # --- csak itt döntjük el, látszódjon-e az Options-ban ---
      defs = [instance.definition.attribute_dictionary(DICT, true),
              instance.attribute_dictionary(DICT, true)]
    
      if show_in_options
        defs.each { |ad| ad["_#{name}_formlabel"] = (display_label || name) }
      else
        # FONTOS: töröld a formlabel kulcsot, különben az Options a mező nevét fogja kirakni
        defs.each { |ad| ad.delete_key("_#{name}_formlabel") rescue nil }
      end
    
      # kötelező érték-inicializálás
      instance.attribute_dictionary(DICT, true)[name] = 0.0
    end

    # -- Sima számmező cm-ben (TEXTBOX) --
    def self.add_dc_number_cm(instance, name, value_cm, display_label=nil)
      set_meta_both(instance, "_#{name}_label",        name)
      set_meta_both(instance, "_#{name}_formlabel",    (display_label || name))
      set_meta_both(instance, "_#{name}_units",        "CENTIMETERS")
      set_meta_both(instance, "_#{name}_displayunits", "CENTIMETERS")
      set_meta_both(instance, "_#{name}_access",       "TEXTBOX")
      set_meta_both(instance, "_#{name}_formulaunits",  "CENTIMETERS")

      # érték (inchben tároljuk, ahogy a SU várja)
      instance.attribute_dictionary(DICT, true)[name] = cm(value_cm)
    end
    
    # Material attribútum létrehozása / képlet beállítása
    # formula_without_equals: pl. 'handle_material' vagy 'Parent!handle_material'
    def self.add_dc_material_formula(instance, formula_without_equals, formlabel: nil)
      # szükséges meta-kulcsok (def + inst)
      set_meta_both(instance, "_material_access",       "FORMULA")
      set_meta_both(instance, "_material_units",        "STRING")
      set_meta_both(instance, "_material_displayunits", "STRING")
      set_meta_both(instance, "_material_label",        "material")
      set_meta_both(instance, "_material_formula",      formula_without_equals.to_s.strip) # NINCS '='
      set_meta_both(instance, "_hasbehaviors",          1.0)
    
      # Opcionális felirat a Component Options ablakhoz
      set_meta_both(instance, "_material_formlabel", (formlabel || ""))
    
      # kötelező értékkulcs az instancén (a definíción nem szükséges)
      instance.attribute_dictionary(DICT, true)["material"] = ""
    
      # (nem kötelező, de sokszor segít a DC-nek észrevenni a változást)
      instance.set_attribute(DICT, "_lastmodified", Time.now.to_f)
    end

    # ---- DEMÓ: írja fel a kijelölt komponensre ----
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
        ['0 Nincs',0], ['180 cm',1], ['135 cm',2],['130 cm',3]
      ]
      add_dc_list(inst, "handle", handle_pairs, 0, :float, "Fogantyú típus")


      handle_material_pairs = [
        ['0 Nincs',''],
        ['Piros',  'Red'],
        ['Zöld',   'Green'],
        ['Kék',    'Blue']
      ]
      add_dc_list(inst, "handle_material", handle_material_pairs, '', :string, "Textúra")

      add_dc_number_cm(inst, "front_thickness", 50.0, "Bútorlap vastagság")

      add_dc_material_formula(inst, 'handle_material')
      #mats = Sketchup.active_model.materials
      #%w[Red Green Blue].each { |n| mats.add(n) unless mats[n] }

      # CHOOSE indexe az OPTIONINDEX("front_type") (1..N)
      add_dc_formula_cm(
        inst,
        "handleoffset",
        'CHOOSE(OPTIONINDEX("front_type"), 0, 26.5, 25, 26.5, 25.35, 23.75, 26.5)',
        "Fogantyú eltolás",
        show_in_options: false
      )

      m.commit_operation
      # Megjegyzés: a DC panel fejléc (inch/cm) felirata csak panel-újranyitásra frissülhet.
    end
  end
end
