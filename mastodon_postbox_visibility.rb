# -*- coding: utf-8 -*-

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

  def initialize(*args)
    initialize_uwm(*args)

    # 公開範囲切り替えボタン
    add_extra_button(:mastodon_visibility, Gtk::WebIcon.new(Plugin[:mastodon].get_skin("private.png"), 16, 16)) { |e|
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
                    item.ssc(:activate) {
                      @visibility = nil
                    }
                    group = item
                  })
      menu.append(Gtk::RadioMenuItem.new(group, "公開").tap { |item|
                    item.active = @visibility == :public
                    item.ssc(:activate) {
                      @visibility = :public
                    }
                  })
      menu.append(Gtk::RadioMenuItem.new(group, "未収載").tap { |item|
                    item.active = @visibility == :unlisted
                    item.ssc(:activate) {
                      @visibility = :unlisted
                    }
                  })
      menu.append(Gtk::RadioMenuItem.new(group, "フォロワー限定").tap { |item|
                    item.active = @visibility == :private
                    item.ssc(:activate) {
                      @visibility = :private
                    }
                  })
      menu.append(Gtk::RadioMenuItem.new(group, "ダイレクト").tap { |item|
                    item.active = @visibility == :direct
                    item.ssc(:activate) {
                      @visibility = :direct
                    }
                  })

      menu.show_all.popup(nil, nil, 0, 0)
    }

    # World切り替え時にボタンの有効状態を制御
    tag = Plugin[:mastodon_postbox_visibility].handler_tag
    @extra_buttons[:mastodon_visibility].ssc_atonce(:expose_event) {
      Plugin[:mastodon_postbox_visibility].on_world_change_current(tags: tag) { |world|
        update_visibility_button_state
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

  def update_visibility_button_state
    if not @extra_buttons[:mastodon_visibility].destroyed?
      current_world, = Plugin.filtering(:world_current, nil)
      @extra_buttons[:mastodon_visibility].sensitive = current_world.class.slug == :mastodon
    end
  end
end

Plugin.create(:mastodon_postbox_visibility) do

end
