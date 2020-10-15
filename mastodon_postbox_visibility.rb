# -*- coding: utf-8 -*-
# frozen_string_literal: true

module Plugin::MastodonPostboxVisibility
  module PostboxExtension; end # prototype
  module PostboxExtensionPrivate
    refine PostboxExtension do
      def widget_mastodon_visibility
        @widget_mastodon_visibility ||= make_widget_mastodon_visibility
      end

      def make_widget_mastodon_visibility
        icon = Gtk::Image.new(Plugin[:mastodon_postbox_visibility].visibility_icon(@visibility).pixbuf(width: 16, height: 16))
        icon.height_request = 16
        icon.width_request = 16

        button = Gtk::Button.new.add(icon)
        button.show_all
        button.ssc(:clicked, &method(:popup_visibility_menu))

        # World切り替え時にボタンの有効状態を制御
        tag = Plugin[:mastodon_postbox_visibility].handler_tag
        button.ssc_atonce(:expose_event) {
          Plugin[:mastodon_postbox_visibility].tap { |plugin|
            plugin.on_world_change_current(tags: tag) { |world|
              update_visibility_button_state
            }
            plugin.on_world_after_created(tags: tag) { |world|
              update_visibility_button_state
            }
          }
          false
        }
        button.ssc(:destroy) {
          Plugin[:mastodon_postbox_visibility].detach(tag)
        }

        button
      end

      def popup_visibility_menu(sender)
        menu = Gtk::Menu.new
        menu.ssc(:selection_done) {
          menu.destroy
          false
        }
        menu.ssc(:cancel) {
          menu.destroy
          false
        }

        group = nil
        menu.append(Gtk::RadioMenuItem.new("デフォルト").tap { |item|
                      item.active = @visibility == nil
                      item.ssc(:toggled) {
                        next unless item.active?
                        self.visibility = nil
                      }
                      group = item
                    })
        menu.append(Gtk::RadioMenuItem.new(group, "公開").tap { |item|
                      item.active = @visibility == :public
                      item.ssc(:toggled) {
                        next unless item.active?
                        self.visibility = :public
                      }
                    })
        menu.append(Gtk::RadioMenuItem.new(group, "未収載").tap { |item|
                      item.active = @visibility == :unlisted
                      item.ssc(:toggled) {
                        next unless item.active?
                        self.visibility = :unlisted
                      }
                    })
        menu.append(Gtk::RadioMenuItem.new(group, "フォロワー限定").tap { |item|
                      item.active = @visibility == :private
                      item.ssc(:toggled) {
                        next unless item.active?
                        self.visibility = :private
                      }
                    })
        menu.append(Gtk::RadioMenuItem.new(group, "ダイレクト").tap { |item|
                      item.active = @visibility == :direct
                      item.ssc(:toggled) {
                        next unless item.active?
                        self.visibility = :direct
                      }
                    })

        menu.show_all.popup(nil, nil, 0, 0)
      end

      def update_visibility_button_state
        if !widget_mastodon_visibility.destroyed?
          current_world, = Plugin.filtering(:world_current, nil)
          widget_mastodon_visibility.sensitive = current_world&.class&.slug == :mastodon
        end
      end
    end
  end

  module PostboxExtension
    using PostboxExtensionPrivate

    def start_post
      super
      if !widget_mastodon_visibility.destroyed?
        widget_mastodon_visibility.sensitive = false
      end
    end

    def end_post
      super
      if !widget_mastodon_visibility.destroyed?
        widget_mastodon_visibility.sensitive = true
      end
    end

    def destroy_if_necessary(*related_widgets)
      super(*related_widgets, widget_mastodon_visibility)
    end

    def generate_box
      super.tap do |postbox|
        until postbox.is_a? Gtk::HBox
          postbox = postbox.children[0]
        end
        postbox.pack_start(widget_mastodon_visibility, false)
      end
    end

    def initialize(*args, **kwrest)
      super(*args, **kwrest)
      Delayer.new {
        update_visibility_button_state
      }
    end

    def visibility=(new_value)
      @visibility = new_value
      if not widget_mastodon_visibility.destroyed?
        widget_mastodon_visibility.child.pixbuf = Plugin[:mastodon_postbox_visibility].visibility_icon(new_value || :default)
                                                    .pixbuf(width: 16, height: 16)
      end
    end
  end
end

Gtk::PostBox.prepend Plugin::MastodonPostboxVisibility::PostboxExtension

Plugin.create(:mastodon_postbox_visibility) do
  
  @skin_fallback_dir = [
    File.join(spec[:path], 'skin'),
    File.join(Plugin[:mastodon].spec[:path], 'icon'),
  ].freeze
  
  @icons = {
    default: 'visibility-default.png',
    public: 'etc.png',
    unlisted: 'unlisted.png',
    private: 'private.png',
    direct: 'direct.png',
  }.freeze

  # mastodon pluginのiconディレクトリを含めてSkinを検索し、
  # Photo modelとして結果を得る
  def visibility_icon(visibility)
    ::Skin::photo(@icons[visibility] || @icons[:default], @skin_fallback_dir)
  end

  {
    default: 'デフォルト',
    public: '公開',
    unlisted: '未収載',
    private: 'フォロワー限定',
    direct: 'ダイレクト'
  }.each do |visibility, label|
    command(:"mastodon_postbox_visibility_#{visibility}",
            name: "公開範囲を#{label}に変更",
            condition: ->(opt) { mastodon?(opt.world) },
            visible: false,
            icon: visibility_icon(visibility),
            role: :postbox) do |opt|
      i_postbox = opt.widget
      postbox, = Plugin.filtering(:gui_get_gtk_widget, i_postbox)
      postbox.visibility = visibility == :default ? nil : visibility
    end
  end
end
