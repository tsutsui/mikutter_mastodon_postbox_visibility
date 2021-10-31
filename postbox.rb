# -*- coding: utf-8 -*-

# original by moguno
# https://github.com/moguno/mikutter-uwm-hommage/blob/f6e343094070f926700f29b32f1b78fb0233df36/postbox.rb

# ポストボックスを魔改造
class Gtk::PostBox
  # ポストボックス右端にボタンを追加する
  def add_extra_button(slug, inner_widget, &clicked)
    button = Gtk::Button.new.add(inner_widget)
    inner_widget.height_request = 16
    inner_widget.width_request = 16
    button.show_all

    button.ssc(:clicked, &clicked)

    if !@extra_button_area.destroyed?
      @extra_button_area.add(button)
    end

    @extra_buttons[slug] = button
  end


  # ポストボックス下にウィジェットを追加する
  def add_extra_widget(slug, factory)
    if @extra_widgets[slug]
      remove_extra_widget(slug)
    end

    @extra_widgets[slug] = { :factory => factory, :widget => factory.create(self) }

    if !@extra_box.destroyed?
      @extra_box.add(@extra_widgets[slug][:widget])
    end
  end


  # ポストボックス下のウィジェットを削除する
  def remove_extra_widget(slug)
    if !@extra_widgets[slug]
      return
    end

    if !@extra_box.destroyed?
      @extra_box.remove(@extra_widgets[slug][:widget])
    end

    @extra_widgets.delete(slug)
  end


  # ポストボックス下のウィジェットを返す
  def extra_widget(slug)
    @extra_widgets[slug]
  end


  # 別のポストボックスにポストボックス下のウィジェットを移植する
  def give_extra_widgets!(to_post)
    @extra_widgets.each { |slug, info|
      remove_extra_widget(slug)
      to_post.add_extra_widget(slug, info[:factory])
    }
  end


  # ポストボックス生成
  alias generate_box_org generate_box

  def generate_box
    @extra_box = Gtk::VBox.new(false)
    post_box = generate_box_org

    # 追加ウィジェットを填めるボックスを追加
    @extra_button_area = if post_box.orientation.respond_to?(:horizontal) # たぶん正しくなくて根本から見直す必要があると思われる
      post_box
    else
      post_box.children[0]
    end

    @extra_box.add(post_box)
  end


  # 投稿キャンセル
  alias cancel_post_org cancel_post

  def cancel_post
    cancel_post_org

    if @options[:delegated_by]
      give_extra_widgets!(@options[:delegated_by])
    end
  end


  #                           ・・・・・
  # お前の凍結能力は俺の能力で既に無効化されていた。
  def freeze()
    @frozen = true
    self
  end


  #           ・・                        ・・・・・・・
  # そして俺は凍結されたふりをした。お前は既に負けていたのだ。
  def frozen?
    @frozen ||= false
    @frozen
  end


  # コンストラクタ
  alias initialize_org initialize

  def initialize(*args, **kwargs)
    @extra_widgets ||= Hash.new
    @extra_buttons ||= Hash.new

    initialize_org(*args, **kwargs)

    if @options[:delegated_by]
      @options[:delegated_by].give_extra_widgets!(self)
    end
  end
end
