/*  Copyright (c) alphaOS
 *  Written by simargl <archpup-at-gmail-dot-com>
 *  Contributor: Yosef Or Boczko <yoseforb-at-gmail-dot-com>
 *  
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *  
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

private class Program : Gtk.Window
{
  const string NAME        = "Emendo";
  const string VERSION     = "2.5.1";
  const string DESCRIPTION = _("Text editor with syntax highlighting");
  const string ICON        = "emendo";
  const string[] AUTHORS   = { "Simargl <archpup-at-gmail-dot-com>", "Yosef Or Boczko <yoseforb-at-gmail-dot-com>", null };
  GLib.Settings                settings;
  Gtk.Button                   button_redo;
  Gtk.Button                   button_undo;
  Gtk.CheckButton              checkbutton_replace_all;
  Gtk.CheckButton              checkbutton_replace_match_case;
  Gtk.ComboBoxText             comboboxtext_scheme;
  Gtk.Dialog                   dialog_question;
  Gtk.Dialog                   dialog_replace;
  Gtk.Dialog                   dialog_save_error;
  Gtk.Entry                    entry_replace;
  Gtk.Entry                    entry_replace_search;
  Gtk.FontButton               fontbutton_preferences;
  Gtk.HeaderBar                headerbar_main;
  Gtk.MenuButton               menubutton;
  Gtk.RecentChooserMenu        recent_chooser_menu;
  Gtk.SearchBar                search_bar;
  Gtk.SearchEntry              search_entry;
  Gtk.SourceBuffer             buffer;
  Gtk.SourceLanguageManager    manager;
  Gtk.SourceStyleSchemeManager style_scheme_manager;
  Gtk.SourceSearchSettings     search_settings;
  Gtk.SourceSearchContext      search_context;
  Gtk.SourceView               view;
  Gtk.SpinButton               spinbutton_indent;
  Gtk.SpinButton               spinbutton_margin;
  Gtk.SpinButton               spinbutton_tab;
  Gtk.Statusbar                statusbar;
  Gtk.Switch                   switch_line;
  Gtk.Switch                   switch_numbers;
  Gtk.Switch                   switch_margin;
  Gtk.Switch                   switch_spaces;
  Gtk.Switch                   switch_wrap;
  Gtk.TextIter                 iter_current;
  Gtk.TextIter                 iter_start;
  Gtk.TextIter                 iter_match_start;
  Gtk.TextIter                 iter_match_end;
  Gtk.TextIter                 iter_sel_start;
  Gtk.TextIter                 iter_sel_end;
  Gtk.ToggleButton             togglebutton_find;
  Gtk.Window                   window;
  Gtk.WrapMode                 text_wrapping;
  Pango.FontDescription        font_desc;
  bool                         line_numbers;
  bool                         highlight_current;
  bool                         right_margin_show;
  bool                         spaces_instead_of_tabs;
  int                          width;
  int                          height;
  int                          indent_width;
  string                       font;
  string                       source_view_style;
  uint                         tab_width;
  uint                         statusbar_id;
  uint                         right_margin_width;
  string                       file;
  
  private Program()
  {
    load_settings();
    construct_ui();
  }
  
  // Load Settings
  private void load_settings()
  {
    settings = new GLib.Settings("org.alphaos.emendo.preferences");
    width = settings.get_int("width");
    height = settings.get_int("height");
    line_numbers = settings.get_boolean("line-numbers");
    highlight_current = settings.get_boolean("highlight-current");
    right_margin_show = settings.get_boolean("right-margin-show");
    right_margin_width = settings.get_uint("right-margin-width");
    var text_wrapping_string = settings.get_string("text-wrapping");
    if (text_wrapping_string == "GTK_WRAP_NONE")
    {
      text_wrapping = Gtk.WrapMode.NONE;
    }
    if (text_wrapping_string == "GTK_WRAP_WORD")
    {
      text_wrapping = Gtk.WrapMode.WORD;
    }
    spaces_instead_of_tabs = settings.get_boolean("spaces-instead-of-tabs");
    indent_width = settings.get_int("indent-width");
    tab_width = settings.get_uint("tab-width");
    font = settings.get_string("font");
    source_view_style = settings.get_string("style");
  }
  
  // Construct UI
  private void construct_ui()
  {
    // New
    var button_new = new Gtk.Button.with_label(_("New"));
    button_new.width_request = 55;
    button_new.valign = Gtk.Align.CENTER;
    button_new.clicked.connect(source_buffer_save_check_new);

    // Save
    var button_save = new Gtk.Button.with_label(_("Save"));
    button_save.width_request = 55;
    button_save.valign = Gtk.Align.CENTER;
    button_save.clicked.connect(file_save);

    // Separators
    var separator_one = new Gtk.Separator(Gtk.Orientation.VERTICAL);
    var separator_two = new Gtk.SeparatorMenuItem();
    var separator_three = new Gtk.SeparatorMenuItem();

    // Undo
    button_undo = new Gtk.Button.from_icon_name("edit-undo-symbolic", Gtk.IconSize.MENU);
    button_undo.valign = Gtk.Align.CENTER;
    button_undo.clicked.connect(action_undo);
    button_undo.set_tooltip_text(_("Undo your last action"));
    button_undo.sensitive = false;
    
    // Redo
    button_redo = new Gtk.Button.from_icon_name("edit-redo-symbolic", Gtk.IconSize.MENU);
    button_redo.valign = Gtk.Align.CENTER;
    button_redo.clicked.connect(action_redo);
    button_redo.set_tooltip_text(_("Redo your last action"));
    button_redo.sensitive = false;

    // Undo/Redo Box
    var undo_redo_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
    undo_redo_box.get_style_context().add_class("linked");
    undo_redo_box.pack_start(button_undo);
    undo_redo_box.pack_start(button_redo);

    // Find
    var togglebutton_find_image = new Gtk.Image.from_icon_name("edit-find-symbolic", Gtk.IconSize.MENU);
    togglebutton_find = new Gtk.ToggleButton();
    togglebutton_find.set_image(togglebutton_find_image);
    togglebutton_find.valign = Gtk.Align.CENTER;
    togglebutton_find.clicked.connect(show_search_bar);
    togglebutton_find.set_tooltip_text(_("Find the entered text in the current file"));

    // Open
    var menuitem_open = new Gtk.MenuItem.with_label(_("Open"));
    menuitem_open.activate.connect(source_buffer_save_check_open);

    // RecentChooser
    var filter = new Gtk.RecentFilter();
    filter.add_mime_type("text/*");
    filter.add_application("emendo");
    recent_chooser_menu  = new Gtk.RecentChooserMenu();
    recent_chooser_menu.set_filter(filter);
    recent_chooser_menu.set_limit(7);
    recent_chooser_menu.set_show_not_found(false);
    recent_chooser_menu.item_activated.connect(recent_chooser_menu_activate);

    // Recent MenuItem
    var menuitem_recent = new Gtk.MenuItem.with_label(_("Recent"));
    menuitem_recent.set_submenu(recent_chooser_menu);

    // Save-As
    var menuitem_save_as = new Gtk.MenuItem.with_label(_("Save As"));
    menuitem_save_as.activate.connect(file_save_as);

    // Replace
    var menuitem_replace = new Gtk.MenuItem.with_label(_("Replace"));
    menuitem_replace.activate.connect(show_dialog_replace);
    
    // Select color
    var menuitem_color_selection = new Gtk.MenuItem.with_label(_("Select Color"));
    menuitem_color_selection.activate.connect(color_selection_dialog);

    // Preferences
    var menuitem_preferences = new Gtk.MenuItem.with_label(_("Preferences"));
    menuitem_preferences.activate.connect(preferences_dialog);

    // About
    var menuitem_about = new Gtk.MenuItem.with_label(_("About"));
    menuitem_about.activate.connect(about_dialog);
    
    // Dropdown Menu
    var menu = new Gtk.Menu();
    menu.append(menuitem_open);
    menu.append(menuitem_recent);
    menu.append(separator_two);
    menu.append(menuitem_save_as);
    menu.append(menuitem_replace);
    menu.append(menuitem_color_selection);
    menu.append(separator_three);
    menu.append(menuitem_preferences);
    menu.append(menuitem_about);
    menu.show_all();
    
    // Dropdown MenuButton
    menubutton = new Gtk.MenuButton();
    menubutton.valign = Gtk.Align.CENTER;
    menubutton.set_popup(menu);
    menubutton.set_image(new Gtk.Image.from_icon_name("emblem-system-symbolic", Gtk.IconSize.MENU));

    // HeaderBar
    headerbar_main = new Gtk.HeaderBar();
    headerbar_main.show_close_button = true;
    headerbar_main.pack_start(button_new);
    headerbar_main.pack_start(button_save);
    headerbar_main.pack_start(separator_one);
    headerbar_main.pack_start(undo_redo_box);
    headerbar_main.pack_end(menubutton);
    headerbar_main.pack_end(togglebutton_find);
    
    // SourceView
    buffer = new Gtk.SourceBuffer(null);
    buffer.set_highlight_syntax(true);
    buffer.modified_changed.connect(update_title);
    buffer.modified_changed.connect(undo_redo_buttons_update);
    
    font_desc = Pango.FontDescription.from_string(font);
    
    view = new Gtk.SourceView.with_buffer(buffer);
    view.set_cursor_visible(true);
    view.set_highlight_current_line(highlight_current);
    view.set_show_line_numbers(line_numbers);
    view.set_insert_spaces_instead_of_tabs(spaces_instead_of_tabs);
    view.set_auto_indent(true);
    view.set_right_margin_position(right_margin_width);
    view.set_show_right_margin(right_margin_show);
    view.set_indent_width(indent_width);
    view.set_tab_width(tab_width);
    view.set_buffer(buffer);
    view.set_left_margin(10);
    view.set_wrap_mode(text_wrapping);
    view.override_font(font_desc);

    // SourceStyleSchemeManager
    style_scheme_manager = new Gtk.SourceStyleSchemeManager();
    Gtk.SourceStyleScheme scheme = style_scheme_manager.get_scheme(source_view_style);
    buffer.set_style_scheme(scheme);
    manager = new Gtk.SourceLanguageManager();
    
    // SearchBar
    search_bar = new Gtk.SearchBar();
    search_entry = new Gtk.SearchEntry();
    search_entry.set_size_request(300, 0);
    var search_bar_button_backward = new Gtk.Button.from_icon_name("go-up-symbolic", Gtk.IconSize.MENU);
    var search_bar_button_forward = new Gtk.Button.from_icon_name("go-down-symbolic", Gtk.IconSize.MENU);
    
    var grid_search_bar = new Gtk.Grid();
    grid_search_bar.attach(search_entry, 0, 0, 1, 1);
    grid_search_bar.attach(search_bar_button_backward, 1, 0, 1, 1);
    grid_search_bar.attach(search_bar_button_forward, 2, 0, 1, 1);

    search_bar.connect_entry(search_entry);
    search_bar.add(grid_search_bar);
    search_entry.search_changed.connect(search_bar_entry_changed);
    search_entry.activate.connect(search_bar_button_forward_clicked);
    search_bar_button_backward.clicked.connect(search_bar_button_backward_clicked);
    search_bar_button_forward.clicked.connect(search_bar_button_forward_clicked);
    
    // ScrolledWindow
    var scrolled_window = new Gtk.ScrolledWindow(null, null);
    scrolled_window.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.ALWAYS);
    scrolled_window.expand = true;
    scrolled_window.add(view);

    // StatusBar
    statusbar = new Gtk.Statusbar();
    statusbar_id = statusbar.get_context_id ("info");

    // Gtk.Grid
    var grid = new Gtk.Grid();
    grid.attach(search_bar, 0, 0, 1, 1);
    grid.attach(scrolled_window, 0, 1, 1, 1);
    grid.attach(statusbar, 0, 2, 1, 1);
    
    // Main window
    window = new Gtk.Window();
    window.set_default_size(width, height);
    window.set_titlebar(headerbar_main);
    window.key_press_event.connect(keyboard_events);
    window.set_icon_name(ICON);
    window.add(grid);
    window.show_all();
    window.delete_event.connect(() => { source_buffer_save_check_quit(); return true; });
    window.scroll_event.connect(font_size_change_on_scroll);
  }

  // Clicked New
  private void file_new()
  {
    file = GLib.Environment.get_tmp_dir() + "/untitled";
    var filenew = File.new_for_path(file);
    try
    {
      filenew.replace_contents("".data, null, false, 0, null, null);
      buffer.set_modified(false);
      get_text(file);
    }
    catch(Error e)
    {
      stderr.printf("error: %s\n", e.message);
    }
  }  

  // Clicked Open
  private void file_open()
  {
    var dialog = new Gtk.FileChooserDialog(_("Open File..."), window, Gtk.FileChooserAction.OPEN,
                                         "gtk-cancel", Gtk.ResponseType.CANCEL,
                                         "gtk-open", Gtk.ResponseType.ACCEPT);
    var dirname = Path.get_dirname(file);
    dialog.set_select_multiple(false);
    dialog.set_current_folder(dirname);
    dialog.set_transient_for(window);
    dialog.set_modal(true);
    dialog.show();
    if (dialog.run() == Gtk.ResponseType.ACCEPT)
    {
      file = dialog.get_filename();
      get_text(file);
    }
    dialog.destroy();
  }

  private void get_text(string file_name)
  {
    try
    {
      uint8[] contents;
      Gtk.SourceLanguage lang;
      GLib.FileInfo info;
      var fileopen = File.new_for_path(file_name);
      info = fileopen.query_info("standard::*",FileQueryInfoFlags.NONE,null);
      var mime_type = ContentType.get_mime_type(info.get_attribute_as_string(FileAttribute.STANDARD_CONTENT_TYPE));
      int64 bytes = info.get_size();
      lang = manager.guess_language(fileopen.get_path(), mime_type);
      fileopen.load_contents(null, out contents, null);
      buffer.begin_not_undoable_action();
      buffer.set_text((string)contents, -1);
      buffer.end_not_undoable_action();
      buffer.set_modified(false);
      buffer.set_language(lang);
      buffer.get_start_iter(out iter_start);
      buffer.place_cursor(iter_start);
      view.scroll_to_iter(iter_start, 0.10, false, 0, 0);
      view.grab_focus();
      statusbar.push(statusbar_id, "%s   %s   %lld bytes".printf(file_name, mime_type, bytes));
      update_title();
    }
    catch (Error e)
    {
      stderr.printf("error: %s\n", e.message);
    }
  }
  
  // Clicked Save
  private void file_save()
  {
    if (file == GLib.Environment.get_tmp_dir() + "/untitled")
    {
      file_save_as();
    }
    else
    {
      var filesave = File.new_for_path(file);
      try
      {
        filesave.replace_contents(buffer.text.data, null, false, 0, null, null);
        buffer.set_modified(false);
        Gtk.TextMark current_mark = buffer.get_insert();
        buffer.get_iter_at_mark(out iter_current, current_mark);
        view.scroll_to_iter(iter_current, 0.10, false, 0, 0);
        view.grab_focus();
        update_title();
      }
      catch(Error e)
      {
        stderr.printf("error: %s\n", e.message);
        var basename = Path.get_basename(file);

        dialog_save_error = new Gtk.MessageDialog(window, Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.NONE, _("Error saving file %s.\nThe file on disk may now be truncated!").printf(basename));
        dialog_save_error.add_button(_("Save As"), Gtk.ResponseType.YES);    
        dialog_save_error.add_button(_("OK"), Gtk.ResponseType.NO);
        dialog_save_error.set_size_request(340, 150);
        dialog_save_error.set_resizable(false);
        dialog_save_error.set_title(_("Error"));
        dialog_save_error.response.connect(dialog_save_error_on_response);
        dialog_save_error.set_default_response(Gtk.ResponseType.NO);
        dialog_save_error.show_all();
        dialog_save_error.run();
        dialog_save_error.destroy();
      }
    }
  }
  
  private void dialog_save_error_on_response(int response_id)
  {
    switch(response_id)
    {
    case Gtk.ResponseType.NO:
      break;
    case Gtk.ResponseType.YES:
      dialog_save_error.destroy();
      file_save_as();
      break;
    }
  }

  // Clicked Save As
  private void file_save_as()
  {
    var save_dialog = new Gtk.FileChooserDialog(_("Save file"), window, Gtk.FileChooserAction.SAVE,
                                                _("Cancel"), Gtk.ResponseType.CANCEL,
                                                _("Save"), Gtk.ResponseType.ACCEPT);
    var dirname = Path.get_dirname(file);
    var basename = Path.get_basename(file);
    save_dialog.set_transient_for(window);
    save_dialog.set_do_overwrite_confirmation(true);
    save_dialog.set_modal(true);
    save_dialog.set_current_folder(dirname);
    save_dialog.set_current_name(basename);
    save_dialog.show();
    if (save_dialog.run() == Gtk.ResponseType.ACCEPT)
    {
      file = save_dialog.get_filename();
      file_save();
      get_text(file);
    }
    save_dialog.destroy();
  }
  
  // Clicked Undo
  private void action_undo()
  {
    view.undo();
    undo_redo_buttons_update();
  }  

  // Clicked Redo
  private void action_redo()
  {
    view.redo();
    undo_redo_buttons_update();
  }
  
  private void undo_redo_buttons_update()
  {
    button_undo.sensitive = buffer.can_undo;
    button_redo.sensitive = buffer.can_redo;
  }
  
  // Searchbar show/hide
  private void show_search_bar()
  {  
    if (search_bar.search_mode_enabled == false)
    {
      togglebutton_find.set_active(true);
      search_bar.search_mode_enabled = true;
      if (buffer.has_selection == true) 
      {
        buffer.get_selection_bounds(out iter_sel_start, out iter_sel_end);
        search_entry.text = buffer.get_text(iter_sel_start, iter_sel_end, true);
      }
      search_entry_change_color("#000000");
      search_entry.grab_focus();
    }
    else
    {
      togglebutton_find.set_active(false);
      search_bar.search_mode_enabled = false;
      search_entry.set_text("");
      if (buffer.has_selection == true) 
      {
        buffer.get_selection_bounds(out iter_sel_start, out iter_sel_end);
        view.scroll_to_iter(iter_sel_start, 0.10, false, 0, 0);
      }
      view.grab_focus();
    }
  }
  
  // On entry changed and forward search
  private void search_from_iter(Gtk.TextIter search_from)
  {
    search_settings = new Gtk.SourceSearchSettings();
    search_context = new Gtk.SourceSearchContext(buffer, search_settings);
    
    search_settings.set_search_text(search_entry.get_text());
    
    bool found = search_context.forward(search_from, out iter_match_start, out iter_match_end);
    if (found == true)
    {
      buffer.select_range(iter_match_start, iter_match_end);
      view.scroll_to_iter(iter_match_start, 0.10, false, 0, 0);
      search_entry_change_color("#000000");
    }
    else
    {
     search_entry_change_color("#FF2C00");
    }
  }
  
  // Search on entry changed
  private void search_bar_entry_changed()
  {
    buffer.get_selection_bounds(out iter_sel_start, out iter_sel_end);
    search_from_iter(iter_sel_start);
    search_context.set_highlight(true);
  }
  
  // Search forward
  private void search_bar_button_forward_clicked()
  {
    buffer.get_selection_bounds(out iter_sel_start, out iter_sel_end);
    search_from_iter(iter_sel_end);
  }
  
  // Search backward
  private void search_bar_button_backward_clicked()
  {
    search_settings = new Gtk.SourceSearchSettings();
    search_context = new Gtk.SourceSearchContext(buffer, search_settings);
    
    buffer.get_selection_bounds(out iter_sel_start, out iter_sel_end);
    
    search_settings.set_search_text(search_entry.get_text());
    
    bool found = search_context.backward(iter_sel_start, out iter_match_start, out iter_match_end);
    if (found == true)
    {
      buffer.select_range(iter_match_start, iter_match_end);
      view.scroll_to_iter(iter_match_start, 0.10, false, 0, 0);
      search_entry_change_color("#000000");
    }
    else
    {
      search_entry_change_color("#FF2C00");
    }
  }
  
  private void search_entry_change_color(string color)
  {
    var rgba = Gdk.RGBA();
    rgba.parse(color);
    search_entry.override_color(Gtk.StateFlags.NORMAL, rgba);
  }

  private void recent_chooser_menu_activate()
  {
    Gtk.RecentInfo info = recent_chooser_menu.get_current_item();
    file = info.get_uri().replace("file://", "");
    try
    {
      Process.spawn_command_line_async("emendo %s".printf(file));
    }
    catch (GLib.Error e)
    {
      stderr.printf ("%s\n", e.message);
    }
  }

  // Replace dialog
  private void show_dialog_replace()
  {
    dialog_replace = new Gtk.Dialog();
    dialog_replace.set_transient_for(window);
    dialog_replace.set_border_width(5);
    dialog_replace.set_property("skip-taskbar-hint", true);
    dialog_replace.set_resizable(false);
    dialog_replace.set_title(_("Find & Replace"));
    
    entry_replace_search = new Gtk.Entry();
    var replace_search_label = new Gtk.Label.with_mnemonic(_("Search for:"));
    if (buffer.has_selection == true) 
    {
      buffer.get_selection_bounds(out iter_sel_start, out iter_sel_end);
      entry_replace_search.text = buffer.get_text(iter_sel_start, iter_sel_end, true);
    }
    entry_replace = new Gtk.Entry();
    var replace_label = new Gtk.Label.with_mnemonic(_("Repace with:"));
    entry_replace.activate.connect(replace_clicked);

    checkbutton_replace_match_case = new Gtk.CheckButton.with_mnemonic(_("Case sensitive"));
    checkbutton_replace_match_case.set_active(true);
    checkbutton_replace_match_case.toggled.connect(focus_entry_replace_search);
    checkbutton_replace_all = new Gtk.CheckButton.with_mnemonic(_("Replace all at once"));
    checkbutton_replace_all.toggled.connect(focus_entry_replace_search);

    var grid_replace = new Gtk.Grid();
    grid_replace.attach(replace_search_label, 0, 0, 1, 1);
    grid_replace.attach(entry_replace_search, 1, 0, 1, 1);
    grid_replace.attach(replace_label, 0, 1, 1, 1);
    grid_replace.attach(entry_replace, 1, 1, 1, 1);
    grid_replace.attach(checkbutton_replace_match_case, 0, 2, 1, 1);
    grid_replace.attach(checkbutton_replace_all, 1, 2, 1, 1);
    
    grid_replace.set_column_spacing(30);
    grid_replace.set_row_spacing(10);
    grid_replace.set_border_width(10);
    grid_replace.set_row_homogeneous(true);
    
    var content = dialog_replace.get_content_area() as Gtk.Box;
    content.pack_start(grid_replace, true, true, 0);
    
    dialog_replace.add_button(_("Close"), Gtk.ResponseType.CLOSE);
    dialog_replace.add_button(_("Find and Replace"), Gtk.ResponseType.OK);
    focus_entry_replace_search();
    togglebutton_find.set_active(false);
    dialog_replace.show_all();
    dialog_replace.response.connect(dialog_replace_response);
    dialog_replace.set_default_response(Gtk.ResponseType.OK);
    dialog_replace.delete_event.connect(() => { search_context.set_highlight(false); dialog_replace.destroy(); return true; });
  }
  
  private void dialog_replace_response(Gtk.Dialog dialog_replace, int response_id)
  {
    switch(response_id)
    {
    case Gtk.ResponseType.OK:
      replace_clicked();
      break;
    case Gtk.ResponseType.CLOSE:
      dialog_replace.destroy();
      search_context.set_highlight(false);
      break;
    }
  }
  
  private void replace_clicked()
  {
    search_settings = new Gtk.SourceSearchSettings();
    search_context = new Gtk.SourceSearchContext(buffer, search_settings);
    if (checkbutton_replace_match_case.get_active())
    {
      search_settings.set_case_sensitive(true);
    }
    buffer.get_selection_bounds(out iter_sel_start, null);
    string search = entry_replace_search.get_text();
    string replace = entry_replace.get_text();
    
    search_settings.set_search_text(search);
    bool found = search_context.forward(iter_sel_start, out iter_match_start, out iter_match_end);
    if (found == true)
    {
      if (checkbutton_replace_all.get_active() == true)
      {
        try
        {
          search_context.replace_all(replace, replace.length);
          search_context.set_highlight(false);
          dialog_replace.destroy();
        }
        catch(Error e)
        {
          stderr.printf("error: %s\n", e.message);
        }
      }
      else
      {
        try
        {
          buffer.select_range(iter_match_start, iter_match_end);
          view.scroll_to_iter(iter_match_start, 0.10, false, 0, 0);
          search_context.replace(iter_match_start, iter_match_end, replace, replace.length);
        }
        catch(Error e)
        {
          stderr.printf("error: %s\n", e.message);
        }
      }
    }
  }
  
  private void focus_entry_replace_search()
  {
    entry_replace_search.grab_focus();
    entry_replace_search.select_region(0, 0);
    entry_replace_search.set_position(-1);
  }
  
  // Color selection dialog
  private void color_selection_dialog()
  {
    var dialog = new Gtk.ColorChooserDialog(_("Select Color"), window);
    var rgba = Gdk.RGBA();
    if (buffer.has_selection == true)
    {
      buffer.get_selection_bounds(out iter_sel_start, out iter_sel_end);
      string text = buffer.get_text(iter_sel_start, iter_sel_end, false);
      if (text.length == 7)
      {
        rgba.parse(text);
        dialog.set_rgba(rgba);
      }
      if (text.length == 6)
      {
        rgba.parse("#" + text);
        iter_sel_start.backward_char();
        buffer.select_range(iter_sel_start, iter_sel_end);
        dialog.set_rgba(rgba);
      }
    }
    dialog.set_property("skip-taskbar-hint", true);
    dialog.set_transient_for(window);
    if (dialog.run() == Gtk.ResponseType.OK)
    {
      rgba = dialog.get_rgba();
      int r = (int)Math.round(rgba.red * 255);
      int g = (int)Math.round(rgba.green * 255);
      int b = (int)Math.round(rgba.blue * 255);
      string selected = "#%02x%02x%02x".printf(r, g, b).up();
      if (buffer.has_selection == true)
      {
        buffer.delete_selection(true, true);
      }
      buffer.insert_at_cursor(selected, selected.length);
    }
    dialog.close();
  }
  
  // Preferences dialog - on font change (1.1)
  private void font_changed()
  {
    font = fontbutton_preferences.get_font().to_string();
    view.override_font(Pango.FontDescription.from_string(font));
    settings.set_string("font", font);
  }
  
  // Preferences dialog - on style scheme combo changed (1.2)
  private void comboboxtext_scheme_changed()
  {
    source_view_style = comboboxtext_scheme.get_active_id();
    Gtk.SourceStyleScheme scheme = style_scheme_manager.get_scheme(source_view_style);
    buffer.set_style_scheme(scheme);
    settings.set_string("style", source_view_style);
  } 
  
  // Preferences dialog - on margin width change (1.3)
  private void margin_width_changed()
  {
    right_margin_width = spinbutton_margin.get_value_as_int();
    view.set_right_margin_position(right_margin_width);
    settings.set_uint("right-margin-width", right_margin_width);
  }  
  
  // Preferences dialog - on indent width change (1.4)
  private void indent_width_changed()
  {
    indent_width = spinbutton_indent.get_value_as_int();
    view.set_indent_width(indent_width);
    settings.set_int("indent-width", indent_width);
  }
  
  // Preferences dialog - on tab width change (1.5)
  private void tab_width_changed()
  {
    tab_width = spinbutton_tab.get_value_as_int();
    view.set_tab_width(tab_width);
    settings.set_uint("tab-width", tab_width);
  }  
  
  // Preferences dialog - on show line numbers change (2.1)
  private void show_line_numbers_changed()
  {
    if (switch_numbers.active)
    {
      line_numbers = true;
    }
    else
    {
      line_numbers = false;
    }
    view.set_show_line_numbers(line_numbers);
    settings.set_boolean("line-numbers", line_numbers);
  }
  
  // Preferences dialog - on highlight current line change (2.2)
  private void highlight_current_line_changed()
  {
    if (switch_line.active)
    {
      highlight_current = true;
    }
    else
    {
      highlight_current = false;
      view.set_highlight_current_line(false);
    }
    view.set_highlight_current_line(highlight_current);
    settings.set_boolean("highlight-current", highlight_current);
  }
  
  // Preferences dialog - on show right margin change (2.3)
  private void show_right_margin_changed()
  {
    if (switch_margin.active)
    {
      right_margin_show = true;
    }
    else
    {
      right_margin_show = false;
    }
    view.set_show_right_margin(right_margin_show);
    settings.set_boolean("right-margin-show", right_margin_show);
  }
  
  // Preferences dialog - on text wrapping change (2.4)
  private void text_wrapping_changed()
  {
    if (switch_wrap.active)
    {
      view.set_wrap_mode(Gtk.WrapMode.WORD);
    }
    else
    {
      view.set_wrap_mode(Gtk.WrapMode.NONE);
    }
    settings.set_string("text-wrapping", view.get_wrap_mode().to_string());
  }
  
  // Preferences dialog - on spaces instead of tabs change (2.5)
  private void spaces_instead_of_tabs_switch_changed()
  {
    if (switch_spaces.active)
    {
      spaces_instead_of_tabs = true;
    }
    else
    {
     spaces_instead_of_tabs = false;
    }
    view.set_insert_spaces_instead_of_tabs(spaces_instead_of_tabs);
    settings.set_boolean("spaces-instead-of-tabs", spaces_instead_of_tabs);
  }
  
  // Preferences dialog
  private void preferences_dialog()
  {
    // Labels
    var label_fontbutton_preferences = new Gtk.Label(_("Editor font"));
    var label_comboboxtext_scheme    = new Gtk.Label(_("Color scheme"));
    var label_spinbutton_margin      = new Gtk.Label(_("Margin width"));
    var label_spinbutton_indent      = new Gtk.Label(_("Indent width"));
    var label_spinbutton_tab         = new Gtk.Label(_("Tab width"));
    var label_switch_numbers         = new Gtk.Label(_("Show line numbers"));
    var label_switch_line            = new Gtk.Label(_("Highlight current line"));
    var label_switch_margin          = new Gtk.Label(_("Show margin on right"));
    var label_switch_wrap            = new Gtk.Label(_("Enable text wrapping"));
    var label_switch_spaces          = new Gtk.Label(_("Insert spaces instead of tabs"));
    
    // Buttons
    fontbutton_preferences = new Gtk.FontButton();
    comboboxtext_scheme    = new Gtk.ComboBoxText();
    spinbutton_margin      = new Gtk.SpinButton.with_range(70, 110, 1);
    spinbutton_indent      = new Gtk.SpinButton.with_range(1, 8, 1);
    spinbutton_tab         = new Gtk.SpinButton.with_range(1, 8, 1);
    switch_numbers         = new Gtk.Switch();
    switch_line            = new Gtk.Switch();
    switch_margin          = new Gtk.Switch();
    switch_wrap            = new Gtk.Switch();
    switch_spaces          = new Gtk.Switch();
    
    // Default values
    fontbutton_preferences.set_font_name(font);
    string[] scheme_ids;
    scheme_ids = style_scheme_manager.get_scheme_ids();
    foreach (string scheme_id in scheme_ids)
    {
      var scheme = style_scheme_manager.get_scheme(scheme_id);
      comboboxtext_scheme.append(scheme.id, scheme.name);
    }
    comboboxtext_scheme.set_active_id   (source_view_style);    
    spinbutton_margin.set_value         (right_margin_width);
    spinbutton_indent.set_value         (indent_width);
    spinbutton_tab.set_value            (tab_width);
    switch_numbers.set_active           (line_numbers);
    switch_line.set_active              (highlight_current);
    switch_margin.set_active            (right_margin_show);
    if (view.get_wrap_mode() == Gtk.WrapMode.WORD)
    {
      switch_wrap.set_active(true);
    }
    switch_spaces.set_active            (spaces_instead_of_tabs);
    
    // Connect signals
    fontbutton_preferences.font_set.connect(font_changed);
    comboboxtext_scheme.changed.connect    (comboboxtext_scheme_changed);
    spinbutton_margin.value_changed.connect(margin_width_changed);
    spinbutton_indent.value_changed.connect(indent_width_changed);
    spinbutton_tab.value_changed.connect   (tab_width_changed);
    switch_numbers.notify["active"].connect(show_line_numbers_changed);
    switch_line.notify["active"].connect   (highlight_current_line_changed);
    switch_margin.notify["active"].connect (show_right_margin_changed);
    switch_wrap.notify["active"].connect   (text_wrapping_changed);
    switch_spaces.notify["active"].connect (spaces_instead_of_tabs_switch_changed);
    
    var headerbar_preferences = new Gtk.HeaderBar();
    headerbar_preferences.set_show_close_button(true);   
    
    var preferences = new Gtk.Dialog();
    preferences.set_titlebar(headerbar_preferences);
    preferences.set_border_width(20);
    preferences.set_transient_for(window);
    preferences.set_property("skip-taskbar-hint", true);
    preferences.set_resizable(false);
    
    // Editor Grid
    var grid_editor = new Gtk.Grid();
    grid_editor.attach(label_fontbutton_preferences, 0, 0, 3, 1);
    grid_editor.attach(fontbutton_preferences,       3, 0, 2, 1);
    grid_editor.attach(label_comboboxtext_scheme,    0, 1, 3, 1);
    grid_editor.attach(comboboxtext_scheme,          3, 1, 2, 1);
    grid_editor.attach(label_spinbutton_margin,      0, 2, 3, 1);
    grid_editor.attach(spinbutton_margin,            3, 2, 2, 1);
    grid_editor.attach(label_spinbutton_indent,      0, 3, 3, 1);
    grid_editor.attach(spinbutton_indent,            3, 3, 2, 1);
    grid_editor.attach(label_spinbutton_tab,         0, 4, 3, 1);
    grid_editor.attach(spinbutton_tab,               3, 4, 2, 1);

    // View Grid
    var grid_view = new Gtk.Grid();
    grid_view.attach(label_switch_numbers, 0, 0, 3, 1);
    grid_view.attach(switch_numbers,       3, 0, 1, 1);
    grid_view.attach(label_switch_line,    0, 1, 3, 1);
    grid_view.attach(switch_line,          3, 1, 1, 1);
    grid_view.attach(label_switch_margin,  0, 2, 3, 1);
    grid_view.attach(switch_margin,        3, 2, 1, 1);
    grid_view.attach(label_switch_wrap,    0, 3, 3, 1);
    grid_view.attach(switch_wrap,          3, 3, 1, 1);
    grid_view.attach(label_switch_spaces,  0, 4, 3, 1);
    grid_view.attach(switch_spaces,        3, 4, 1, 1);
    
    grid_editor.set_column_spacing(10);
    grid_editor.set_row_spacing(15);
    grid_editor.set_column_homogeneous(true);
    
    grid_view.set_column_spacing(10);
    grid_view.set_row_spacing(21);
    grid_view.set_column_homogeneous(true);
    
    // Stack and Switcher
    var stack = new Gtk.Stack();
    stack.set_transition_duration(500);
    stack.add_titled(grid_editor, "editor", _("Editor"));
    stack.add_titled(grid_view,   "view",   _("View"));
    stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
    
    var content = preferences.get_content_area() as Gtk.Box;
    content.pack_start(stack, false, false, 0);
    
    var switcher = new Gtk.StackSwitcher();
    switcher.set_stack(stack);
    switcher.set_border_width(4);
    
    headerbar_preferences.set_custom_title(switcher);
    preferences.show_all();
  }
  
  // Update Title
  private void update_title()
  {
    var basename = Path.get_basename(file);
    if (buffer.get_modified()) 
    {
      headerbar_main.set_title("* %s".printf(basename));
    }
    else
    {
      headerbar_main.set_title("%s".printf(basename));
    }
  }

  // Keyboard events - New, Open, Save, Undo, Redo, Find, Replace, Quit, Full screen toggle
  private bool keyboard_events(Gdk.EventKey event)
  {
    string key = Gdk.keyval_name(event.keyval);
    if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0 && (key=="n" || key=="N"))
    {
      file_open();
    }    
    if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0 && (key=="o" || key=="O"))
    {
      file_open();
    }    
    if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0 && (key=="s" || key=="S"))
    {
      file_save();
    }    
    if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0 && (key=="z" || key=="Z"))
    {
      action_undo();
      return true;
    }    
    if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0 && (key=="y" || key=="Y"))
    {
      action_redo();
      return true;
    }    
    if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0 && (key=="f" || key=="F"))
    {
      show_search_bar();
    }    
    if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0 && (key=="h" || key=="H"))
    {
      show_dialog_replace();
    }
    if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0 && (key=="q" || key=="Q"))
    {
      source_buffer_save_check_quit();
    }
    if (key=="F9")
    {
      color_selection_dialog();
    }   
    if (key=="F10")
    {
      menubutton.set_active(true);
    }
    if (key=="F11")
    {
      if ((window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) != 0)
      {
        window.unfullscreen();
        statusbar.show();
      }
      else
      {
        window.fullscreen();
        statusbar.hide();
      }
    }
    return false;
  }

  private bool font_size_change_on_scroll(Gdk.EventScroll event)
  {
    double size = font_desc.get_size();
    if ((event.state & Gdk.ModifierType.CONTROL_MASK) > 0)
    {
      if (event.direction == Gdk.ScrollDirection.UP)
      { 
        size = (size + size * 0.08);
        if (size > 72000)
        {
          return false;
        }             
      }
      if (event.direction == Gdk.ScrollDirection.DOWN)
      {
        size = (size - size * 0.08);
        if (size < 6000)
        {
          return false;
        }         
      }
      font_desc.set_size((int)size);
      view.override_font(font_desc);     
      font = font_desc.to_string();
      settings.set_string("font", font);
    }
    return true;
  }
  
  // Save settings
  private void save_settings()
  {
    window.get_size(out width, out height);
    settings.set_int("width", width);
    settings.set_int("height", height);
    GLib.Settings.sync();
  }
  
  // Offer to save changes dialog
  private void offer_to_save_changes_dialog()
  { 
    var basename = Path.get_basename(file);
    
    dialog_question = new Gtk.MessageDialog(window, Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE, _("The file '%s' is not saved.\nDo you want to save it before closing?").printf(basename));
    dialog_question.add_button(_("Cancel"), Gtk.ResponseType.CANCEL);    
    dialog_question.add_button(_("No"), Gtk.ResponseType.NO);
    dialog_question.add_button(_("Yes"), Gtk.ResponseType.YES);
    dialog_question.set_size_request(340, 150);
    dialog_question.set_resizable(false);
    dialog_question.set_title(_("Question"));
    dialog_question.set_default_response(Gtk.ResponseType.YES);
    dialog_question.show_all();
  }  
  
  // Offer to save changes / New
  private void source_buffer_save_check_new()
  {
    if (buffer.get_modified())
    {
      offer_to_save_changes_dialog();
      dialog_question.response.connect(dialog_question_new_on_response);
    }
    else
    {
      file_new();
    }    
  }
  
  private void dialog_question_new_on_response(int response_id)
  {
    switch(response_id)
    {
      case Gtk.ResponseType.CANCEL:
        break;
      case Gtk.ResponseType.YES:
        file_save();
        file_new();
        break;
      case Gtk.ResponseType.NO:
        file_new();
        break;
    }
    dialog_question.destroy();
  }

  // Offer to save changes / Open
  private void source_buffer_save_check_open()
  {
    if (buffer.get_modified())
    {
      offer_to_save_changes_dialog();
      dialog_question.response.connect(dialog_question_open_on_response);
    }
    else
    {
      file_open();
    }  
  }
  
  private void dialog_question_open_on_response(int response_id)
  {
    switch(response_id)
    {
      case Gtk.ResponseType.CANCEL:
        break;
      case Gtk.ResponseType.YES:
        file_save();
        file_open();
        break;
      case Gtk.ResponseType.NO:
        file_open();
        break;
    }
    dialog_question.destroy();
  }

  // Offer to save changes / Quit
  private void source_buffer_save_check_quit()
  {
    if (buffer.get_modified())
    {
      offer_to_save_changes_dialog();
      dialog_question.response.connect(dialog_question_quit_on_response);
    }
    else
    {
      save_settings();
      Gtk.main_quit();
    }  
  }
  
  private void dialog_question_quit_on_response(int response_id)
  {
    switch(response_id)
    {
      case Gtk.ResponseType.CANCEL:
        break;
      case Gtk.ResponseType.YES:
        file_save();
        save_settings();
        Gtk.main_quit();
        break;
      case Gtk.ResponseType.NO:
        save_settings();
        Gtk.main_quit();
        break;
    }
    dialog_question.destroy();
  }

  // Clicked About
  private void about_dialog()
  {
    var about = new Gtk.AboutDialog();
    about.set_program_name(NAME);
    about.set_version(VERSION);
    about.set_comments(DESCRIPTION);
    about.set_logo_icon_name(ICON);
    about.set_authors(AUTHORS);
    about.set_copyright("Copyright \xc2\xa9 alphaOS");
    about.set_website("http://alphaos.tuxfamily.org");
    about.set_property("skip-taskbar-hint", true);
    about.set_transient_for(window);
    about.license_type = Gtk.License.GPL_3_0;
    about.run();
    about.hide();
  }
  
  // Start program
  private void run(string[] args)
  {
    file = GLib.Environment.get_tmp_dir() + "/untitled";
    if (args.length >= 2)
    {
      file = args[1];
      get_text(file);
    }
    else
    {
      file_new();
    }
  }
  
  // The main method
  static int main(string[] args)
  {
    Gtk.init (ref args);
    var Emendo = new Program();
    Emendo.run(args);
    Gtk.main();
    return 0;
  }
}
