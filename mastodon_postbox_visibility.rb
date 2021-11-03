# -*- coding: utf-8 -*-
# frozen_string_literal: true

# uwm-hommageがインストールされている場合は先にロードする、無い場合はPostBoxにパッチを当てる
unless Miquire::Plugin.load('mikutter-uwm-hommage')
  require_relative 'postbox'
end

# uwm-hommageでモンキーパッチされたPostBoxをさらに改造するぞ!
class Gtk::PostBox
  alias start_post_uwm start_post

  def start_post
    start_post_uwm

    if !@extra_buttons[:mastodon_visibility].destroyed?
      @extra_buttons[:mastodon_visibility].sensitive = false
    end
  end

  alias end_post_uwm end_post

  def end_post
    end_post_uwm
    
    if !@extra_buttons[:mastodon_visibility].destroyed?
      @extra_buttons[:mastodon_visibility].sensitive = true
    end
  end

  alias destroy_if_necessary_uwm destroy_if_necessary

  def destroy_if_necessary(*related_widgets)
    destroy_if_necessary_uwm(*related_widgets, @extra_buttons[:mastodon_visibility])
  end
  
  alias initialize_uwm initialize

  def initialize(*args, visibility: nil, **kwrest)
    initialize_uwm(*args, visibility: visibility, **kwrest)

    # 公開範囲切り替えボタン
    icon = Gtk::Image.new(pixbuf: Plugin[:mastodon_postbox_visibility].visibility_icon(visibility).pixbuf(width: 16, height: 16))
    add_extra_button(:mastodon_visibility, icon) { |e|
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
      menu.append(Gtk::RadioMenuItem.new(nil, "デフォルト").tap { |item|
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
    }

    # World切り替え時にボタンの有効状態を制御
    tag = Plugin[:mastodon_postbox_visibility].handler_tag
    @extra_buttons[:mastodon_visibility].ssc_atonce(:realize) {
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
    @extra_buttons[:mastodon_visibility].ssc(:destroy) {
      Plugin[:mastodon_postbox_visibility].detach(tag)
    }
    Delayer.new {
      update_visibility_button_state
    }
  end

  def visibility=(new_value)
    @visibility = new_value
    if not @extra_buttons[:mastodon_visibility].destroyed?
      @extra_buttons[:mastodon_visibility].child.pixbuf = Plugin[:mastodon_postbox_visibility].visibility_icon(new_value || :default)
                                                            .pixbuf(width: 16, height: 16)
    end
  end

  def update_visibility_button_state
    if not @extra_buttons[:mastodon_visibility].destroyed?
      current_world, = Plugin.filtering(:world_current, nil)
      @extra_buttons[:mastodon_visibility].sensitive = current_world&.class&.slug == :mastodon
    end
  end
end

Plugin.create(:mastodon_postbox_visibility) do
  
  @skin_fallback_dir = [
    File.join(spec[:path], 'skin'),
    File.join(Plugin[:mastodon_gtk].spec[:path], 'icon'),
  ].compact.freeze
  
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
