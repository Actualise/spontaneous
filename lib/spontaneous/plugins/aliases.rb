# encoding: UTF-8


module Spontaneous::Plugins
  module Aliases

    def self.configure(base)
      base.many_to_one :target, :class => base, :reciprocal => :aliases
      base.one_to_many :aliases, :class => base, :key => :target_id, :reciprocal => :target
      base.add_association_dependencies :aliases => :destroy
    end

    module ClassMethods
      def alias_of(*class_list)
        @alias_classes = class_list
        extend  ClassAliasMethods
        include AliasMethods
        include PageAliasMethods if page?
      end

      alias_method :aliases, :alias_of

      def targets
        targets = []
        target_classes.each do |target_class|
          targets += target_class.sti_subclasses_array
        end
        S::Content.filter(sti_key => targets.map { |t| t.to_s }).all
      end

      def target_classes
        @target_classes ||= @alias_classes.map { |c| c.to_s.constantize }
      end

      def alias?
        false
      end
    end

    module InstanceMethods
      def alias_title
        fields[:title].to_s
      end

      def alias_icon_field
        if field = fields.detect { |f| f.image? }
          field
        else
          nil
        end
      end
    end

    module ClassAliasMethods
      def alias?
        true
      end
    end

    # included only in instances that are aliases
    module AliasMethods
      def alias?
        true
      end

      def field?(field_name)
        super || target.class.field?(field_name)
      end

      def method_missing(method, *args)
        if target && target.respond_to?(method)
          if block_given?
            target.__send__(method, *args, &Proc.new)
          else
            target.__send__(method, *args)
          end
        else
          super
        end
      end


      def find_named_style(style_name)
        super or target.find_named_style(style_name)
      end

      def style
        if self.class.styles.empty?
          target.resolve_style(style_sid)
        else
          self.resolve_style(self.style_sid) or target.resolve_style(self.style_sid)
        end
      end

      def styles
        @styles ||= Spontaneous::Collections::PrototypeSet.new(target, :styles)
      end

      def to_hash
        super.merge(:target => target.to_shallow_hash, :alias_title => target.alias_title, :alias_icon => target.alias_icon_field.to_hash)
      end
    end

    module PageAliasMethods
      def path
        @_path ||= [parent.path, target.slug].join(S::SLASH)
      end

      def calculate_path
        ""
      end

      def layout
        # if this alias class has no layouts defined, then just use the one set on the target
        if self.class.layouts.empty?
          target.resolve_layout(self.style_sid)
        else
          # but if it does have layouts defined, use them
          self.resolve_layout(self.style_sid) or target.resolve_layout(self.style_sid)
        end
      end

      def find_named_layout(layout_name)
        super or target.find_named_layout(layout_name)
      end
    end
  end
end
