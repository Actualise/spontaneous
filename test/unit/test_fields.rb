# encoding: UTF-8

require File.expand_path('../../test_helper', __FILE__)

class FieldsTest < MiniTest::Spec

  def setup
    @site = setup_site
    Site.publishing_method = :immediate
  end

  def teardown
    teardown_site
  end

  context "Fields" do
    setup do
      class ::Page < Spontaneous::Page; end
      class ::Piece < Spontaneous::Piece; end
    end

    teardown do
      Object.send(:remove_const, :Page)
      Object.send(:remove_const, :Piece)
    end

    context "New content instances" do
      setup do
        @content_class = Class.new(Piece) do
          field :title, :default => "Magic"
          field :thumbnail, :image
        end
        @instance = @content_class.new
      end

      should "have fields with values defined by prototypes" do
        f = @instance.fields[:title]
        f.class.should == Spontaneous::FieldTypes::StringField
        f.value.should == "Magic"
      end

      should "have shortcut access methods to fields" do
        @instance.fields.thumbnail.should == @instance.fields[:thumbnail]
      end
      should "have a shortcut setter on the Content fields" do
        @instance.fields.title = "New Title"
      end

      should "have a shortcut getter on the Content instance itself" do
        @instance.title.should == @instance.fields[:title]
      end

      should "have a shortcut setter on the Content instance itself" do
        @instance.title = "Boing!"
        @instance.fields[:title].value.should == "Boing!"
      end
    end

    context "Overwriting fields" do
      setup do
        @class1 = Class.new(Piece) do
          field :title, :string, :default => "One"
          field :date, :string
        end
        @class2 = Class.new(@class1) do
          field :title, :image, :default => "Two"
        end
        @instance = @class2.new
      end

      should "overwrite field definitions" do
        @class2.fields.first.name.should == :title
        @class2.fields.last.name.should == :date
        @class2.fields.length.should == 2
        @instance.title.class.should == Spontaneous::FieldTypes::ImageField
        @instance.title.value.to_s.should == "Two"
      end
    end
    context "Field Prototypes" do
      setup do
        @content_class = Class.new(Piece) do
          field :title
          field :synopsis, :string
        end
        @content_class.field :complex, :image, :default => "My default", :comment => "Use this to"
      end

      should "be creatable with just a field name" do
        @content_class.field_prototypes[:title].must_be_instance_of(Spontaneous::Prototypes::FieldPrototype)
        @content_class.field_prototypes[:title].name.should == :title
      end

      should "work with just a name & options" do
        @content_class.field :minimal, :default => "Small"
        @content_class.field_prototypes[:minimal].name.should == :minimal
        @content_class.field_prototypes[:minimal].default.should == "Small"
      end
      should "map :string type to FieldTypes::Text" do
        @content_class.field_prototypes[:synopsis].field_class.should == Spontaneous::FieldTypes::StringField
      end

      should "be listable" do
        @content_class.field_names.should == [:title, :synopsis, :complex]
      end

      should "be testable for existance" do
        @content_class.field?(:title).should be_true
        @content_class.field?(:synopsis).should be_true
        @content_class.field?(:non_existant).should be_false
        i = @content_class.new
        i.field?(:title).should be_true
        i.field?(:non_existant).should be_false
      end


      context "default values" do
        setup do
          @prototype = @content_class.field_prototypes[:title]
        end

        should "default to basic string class" do
          @prototype.field_class.should == Spontaneous::FieldTypes::StringField
        end

        should "default to a value of ''" do
          @prototype.default.should == ""
        end

        should "match name to type if sensible" do
          content_class = Class.new(Piece) do
            field :image
            field :date
            field :chunky
          end

          content_class.field_prototypes[:image].field_class.should == Spontaneous::FieldTypes::ImageField
          content_class.field_prototypes[:date].field_class.should == Spontaneous::FieldTypes::DateField
          content_class.field_prototypes[:chunky].field_class.should == Spontaneous::FieldTypes::StringField
        end
      end

      context "Field titles" do
        setup do
          @content_class = Class.new(Piece) do
            field :title
            field :having_fun_yet
            field :synopsis, :title => "Custom Title"
            field :description, :title => "Simple Description"
          end
          @title = @content_class.field_prototypes[:title]
          @having_fun = @content_class.field_prototypes[:having_fun_yet]
          @synopsis = @content_class.field_prototypes[:synopsis]
          @description = @content_class.field_prototypes[:description]
        end

        should "default to a sensible title" do
          @title.title.should == "Title"
          @having_fun.title.should == "Having Fun Yet"
          @synopsis.title.should == "Custom Title"
          @description.title.should == "Simple Description"
        end
      end
      context "option parsing" do
        setup do
          @prototype = @content_class.field_prototypes[:complex]
        end

        should "parse field class" do
          @prototype.field_class.should == Spontaneous::FieldTypes::ImageField
        end

        should "parse default value" do
          @prototype.default.should == "My default"
        end

        should "parse ui comment" do
          @prototype.comment.should == "Use this to"
        end
      end

      context "sub-classes" do
        setup do
          @subclass = Class.new(@content_class) do
            field :child_field
          end
          @subsubclass = Class.new(@subclass) do
            field :distant_relation
          end
        end

        should "inherit super class's field prototypes" do
          @subclass.field_names.should == [:title, :synopsis, :complex, :child_field]
          @subsubclass.field_names.should == [:title, :synopsis, :complex, :child_field, :distant_relation]
        end

        should "deal intelligently with manual setting of field order" do
          @reordered_class = Class.new(@subsubclass) do
            field_order :child_field, :complex
          end
          @reordered_class.field_names.should == [:child_field, :complex, :title, :synopsis, :distant_relation]
        end
      end
    end

    context "Values" do
      setup do
        @field_class = Class.new(FieldTypes::Field) do
          def outputs
            [:html, :plain, :fancy]
          end
          def generate_html(value)
            "<#{value}>"
          end
          def generate_plain(value)
            "*#{value}*"
          end

          def generate(output, value)
            case output
            when :fancy
              "#{value}!"
            else
              value
            end
          end
        end
        @field = @field_class.new
      end

      should "be transformed by the update method" do
        @field.value = "Hello"
        @field.value.should == "<Hello>"
        @field.value(:html).should == "<Hello>"
        @field.value(:plain).should == "*Hello*"
        @field.value(:fancy).should == "Hello!"
        @field.unprocessed_value.should == "Hello"
      end

      should "appear in the to_s method" do
        @field.value = "String"
        @field.to_s.should == "<String>"
        @field.to_s(:html).should == "<String>"
        @field.to_s(:plain).should == "*String*"
      end

      should "escape ampersands by default" do
        field_class = Class.new(FieldTypes::StringField) do
        end
        field = field_class.new
        field.value = "Hello & Welcome"
        field.value(:html).should == "Hello &amp; Welcome"
        field.value(:plain).should == "Hello & Welcome"
      end

      should "not process values coming from db" do
        content_class = Class.new(Piece)

        content_class.field :title do
          def generate_html(value)
            "<#{value}>"
          end
        end
        instance = content_class.new
        instance.fields.title = "Monkey"
        instance.save

        new_content_class = Class.new(Piece)
        new_content_class.field :title do
          def generate_html(value)
            "*#{value}*"
          end
        end
        instance = new_content_class[instance.id]
        instance.fields.title.value.should == "<Monkey>"
      end
    end

    context "field instances" do
      setup do
        ::CC = Class.new(Piece) do
          field :title, :default => "Magic" do
            def generate_html(value)
              "*#{value}*"
            end
          end
        end
        @instance = CC.new
      end

      teardown do
        Object.send(:remove_const, :CC)
      end

      should "have a link back to their owner" do
        @instance.fields.title.owner.should == @instance
      end

      should "eval blocks from prototype defn" do
        f = @instance.fields.title
        f.value = "Boo"
        f.value.should == "*Boo*"
        f.unprocessed_value.should == "Boo"
      end

      should "have a reference to their prototype" do
        f = @instance.fields.title
        f.prototype.should == CC.field_prototypes[:title]
      end

      should "return the item which isnt empty when using the / method" do
        a = CC.new(:title => "")
        b = CC.new(:title => "b")
        (a.title / b.title).should == b.title
        a.title = "a"
        (a.title / b.title).should == a.title
      end
      should "return the item which isnt empty when using the | method" do
        a = CC.new(:title => "")
        b = CC.new(:title => "b")
        (a.title | b.title).should == b.title
        a.title = "a"
        (a.title | b.title).should == a.title
      end
    end

    context "Field value persistence" do
      setup do
        class ::PersistedField < Piece
          field :title, :default => "Magic"
        end
      end
      teardown do
        Object.send(:remove_const, :PersistedField)
      end

      should "work" do
        instance = ::PersistedField.new
        instance.fields.title.value = "Changed"
        instance.save
        id = instance.id
        instance = ::PersistedField[id]
        instance.fields.title.value.should == "Changed"
      end
    end

    context "Value version" do
      setup do
        class ::PersistedField < Piece
          field :title, :default => "Magic"
        end
      end
      teardown do
        Object.send(:remove_const, :PersistedField)
      end

      should "be increased after a change" do
        instance = ::PersistedField.new
        instance.fields.title.version.should == 0
        instance.fields.title.value = "Changed"
        instance.save
        instance = ::PersistedField[instance.id]
        instance.fields.title.value.should == "Changed"
        instance.fields.title.version.should == 1
      end

      should "not be increased if the value remains constant" do
        instance = ::PersistedField.new
        instance.fields.title.version.should == 0
        instance.fields.title.value = "Changed"
        instance.save
        instance = ::PersistedField[instance.id]
        instance.fields.title.value = "Changed"
        instance.save
        instance = ::PersistedField[instance.id]
        instance.fields.title.value.should == "Changed"
        instance.fields.title.version.should == 1
        instance.fields.title.value = "Changed!"
        instance.save
        instance = ::PersistedField[instance.id]
        instance.fields.title.version.should == 2
      end
    end

    context "Available output formats" do
      should "include HTML & PDF and default to default value" do
        f = FieldTypes::Field.new
        f.value = "Value"
        f.to_html.should == "Value"
        f.to_pdf.should == "Value"
      end
    end

    context "Markdown fields" do
      setup do
        class ::MarkdownContent < Piece
          field :text1, :markdown
          field :text2, :text
        end
        @instance = MarkdownContent.new
      end
      teardown do
        Object.send(:remove_const, :MarkdownContent)
      end

      should "be available as the :markdown type" do
        MarkdownContent.field_prototypes[:text1].field_class.should == Spontaneous::FieldTypes::MarkdownField
      end
      should "be available as the :text type" do
        MarkdownContent.field_prototypes[:text2].field_class.should == Spontaneous::FieldTypes::MarkdownField
      end

      should "process input into HTML" do
        @instance.text1 = "*Hello* **World**"
        @instance.text1.value.should == "<p><em>Hello</em> <strong>World</strong></p>\n"
      end

      should "use more sensible linebreaks" do
        @instance.text1 = "With\nLinebreak"
        @instance.text1.value.should == "<p>With<br />\nLinebreak</p>\n"
        @instance.text2 = "With  \nLinebreak"
        @instance.text2.value.should == "<p>With<br />\nLinebreak</p>\n"
      end
    end

    context "Editor classes" do
      should "be defined in base types" do
        base_class = Spontaneous::FieldTypes::ImageField
        base_class.editor_class.should == "Spontaneous.FieldTypes.ImageField"
        base_class = Spontaneous::FieldTypes::DateField
        base_class.editor_class.should == "Spontaneous.FieldTypes.DateField"
        base_class = Spontaneous::FieldTypes::MarkdownField
        base_class.editor_class.should == "Spontaneous.FieldTypes.MarkdownField"
        base_class = Spontaneous::FieldTypes::StringField
        base_class.editor_class.should == "Spontaneous.FieldTypes.StringField"
      end

      should "be inherited in subclasses" do
        base_class = Spontaneous::FieldTypes::ImageField
        @field_class = Class.new(base_class)
        @field_class.stubs(:name).returns("CustomField")
        @field_class.editor_class.should == base_class.editor_class
        @field_class2 = Class.new(@field_class)
        @field_class2.stubs(:name).returns("CustomField2")
        @field_class2.editor_class.should == base_class.editor_class
      end
    end

    context "WebVideo fields" do
      setup do
        @content_class = Class.new(::Piece) do
          field :video, :webvideo
        end
        @content_class.stubs(:name).returns("ContentClass")
        @instance = @content_class.new
      end

      should "have their own editor type" do
        @content_class.fields.video.export(nil)[:type].should == "Spontaneous.FieldTypes.WebVideoField"
        @instance.video = "http://www.youtube.com/watch?v=_0jroAM_pO4&feature=feedrec_grec_index"
        fields  = @instance.export(nil)[:fields]
        fields[0][:processed_value].should == @instance.video.render(:html, :width => 480, :height => 270)
      end

      should "recognise youtube URLs" do
        @instance.video = "http://www.youtube.com/watch?v=_0jroAM_pO4&feature=feedrec_grec_index"
        @instance.video.value.should == "http://www.youtube.com/watch?v=_0jroAM_pO4&amp;feature=feedrec_grec_index"
        @instance.video.id.should == "_0jroAM_pO4"
        @instance.video.video_type.should == "youtube"
      end

      should "recognise Vimeo URLs" do
        @instance.video = "http://vimeo.com/31836285"
        @instance.video.value.should == "http://vimeo.com/31836285"
        @instance.video.id.should == "31836285"
        @instance.video.video_type.should == "vimeo"
      end

      context "with player settings" do
        setup do
          @content_class.field :video2, :webvideo, :player => {
            :width => 680, :height => 384,
            :fullscreen => true, :autoplay => true, :loop => true,
            :showinfo => false,
            :youtube => { :theme => 'light', :hd => true, :controls => false },
            :vimeo => { :color => "ccc", :api => true }
          }
          @instance = @content_class.new
          @field = @instance.video2
        end

        should "use the configuration in the youtube player HTML" do
          @field.value = "http://www.youtube.com/watch?v=_0jroAM_pO4&feature=feedrec_grec_index"
          html = @field.render(:html)
          html.should =~ /^<iframe/
          html.should =~ %r{src="http://www\.youtube\.com/embed/_0jroAM_pO4}
          html.should =~ /width="680"/
          html.should =~ /height="384"/
          html.should =~ /theme=light/
          html.should =~ /hd=1/
          html.should =~ /fs=1/
          html.should =~ /controls=0/
          html.should =~ /autoplay=1/
          html.should =~ /showinfo=0/
          html.should =~ /showsearch=0/
          @field.render(:html, :youtube => {:showsearch => 1}).should =~ /showsearch=1/
          @field.render(:html, :youtube => {:theme => 'dark'}).should =~ /theme=dark/
          @field.render(:html, :width => 100).should =~ /width="100"/
          @field.render(:html, :loop => true).should =~ /loop=1/
        end

        should "use the configuration in the Vimeo player HTML" do
          @field.value = "http://vimeo.com/31836285"
          html = @field.render(:html)
          html.should =~ /^<iframe/
          html.should =~ %r{src="http://player\.vimeo\.com/video/31836285}
          html.should =~ /width="680"/
          html.should =~ /height="384"/
          html.should =~ /color=ccc/
          html.should =~ /webkitAllowFullScreen="yes"/
          html.should =~ /allowFullScreen="yes"/
          html.should =~ /autoplay=1/
          html.should =~ /title=0/
          html.should =~ /byline=0/
          html.should =~ /portrait=0/
          html.should =~ /api=1/
          @field.render(:html, :vimeo => {:color => 'f0abcd'}).should =~ /color=f0abcd/
          @field.render(:html, :loop => true).should =~ /loop=1/
          @field.render(:html, :title => true).should =~ /title=1/
          @field.render(:html, :title => true).should =~ /byline=0/
        end

        should "provide a version of the YouTube player params in JSON/JS format" do
          @field.value = "http://www.youtube.com/watch?v=_0jroAM_pO4&feature=feedrec_grec_index"
          json = JSON.parse(@field.render(:json))
          json[:"tagname"].should == "iframe"
          json[:"tag"].should == "<iframe/>"
          attr = json[:"attr"]
          attr.must_be_instance_of(Hash)
          attr[:"src"].should =~ %r{^http://www\.youtube\.com/embed/_0jroAM_pO4}
          attr[:"src"].should =~ /theme=light/
          attr[:"src"].should =~ /hd=1/
          attr[:"src"].should =~ /fs=1/
          attr[:"src"].should =~ /controls=0/
          attr[:"src"].should =~ /autoplay=1/
          attr[:"src"].should =~ /showinfo=0/
          attr[:"src"].should =~ /showsearch=0/
          attr[:"width"].should == 680
          attr[:"height"].should == 384
          attr[:"frameborder"].should == "0"
          attr[:"type"].should == "text/html"
        end

        should "provide a version of the Vimeo player params in JSON/JS format" do
          @field.value = "http://vimeo.com/31836285"
          json = JSON.parse(@field.render(:json))
          json[:"tagname"].should == "iframe"
          json[:"tag"].should == "<iframe/>"
          attr = json[:"attr"]
          attr.must_be_instance_of(Hash)
          attr[:"src"].should =~ /color=ccc/
          attr[:"src"].should =~ /autoplay=1/
          attr[:"src"].should =~ /title=0/
          attr[:"src"].should =~ /byline=0/
          attr[:"src"].should =~ /portrait=0/
          attr[:"src"].should =~ /api=1/
          attr[:"webkitAllowFullScreen"].should == "yes"
          attr[:"allowFullScreen"].should == "yes"
          attr[:"width"].should == 680
          attr[:"height"].should == 384
          attr[:"frameborder"].should == "0"
          attr[:"type"].should == "text/html"
        end
      end

    end
  end
end
