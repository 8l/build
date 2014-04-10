/*  Copyright (c) alphaOS
 *  Written by simargl <archpup-at-gmail-dot-com>
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
  const string NAME        = "Taeni";
  const string VERSION     = "1.4.2";
  const string DESCRIPTION = _("Terminal emulator based on GTK+ and VTE");
  const string ICON        = "utilities-terminal";
  const string[] AUTHORS   = { "Simargl <archpup-at-gmail-dot-com>", null };
  
  Vte.Terminal term;
  Gtk.Dialog preferences;
  Gtk.Menu context_menu;
  Gtk.MenuItem context_copy;
  Gtk.MenuItem context_paste;
  Gtk.MenuItem context_separator;
  Gtk.MenuItem context_select_all;
  Gtk.Window window;
  
  Gtk.Label preferences_font_label;
  Gtk.Label preferences_bg_label;
  Gtk.Label preferences_fg_label;
  
  Gtk.FontButton preferences_font_button;
  Gtk.ColorButton preferences_bg_button;
  Gtk.ColorButton preferences_fg_button;
  
  string argument;
  string command;
  string terminal_bgcolor;
  string terminal_fgcolor;
  string terminal_font;
  int width;
  int height;  
  
  GLib.Settings settings;
  
  private Program()
  {
    load_settings();
    show_ui();
  }

  private void load_settings()
  {
    settings = new GLib.Settings("org.alphaos.taeni.preferences");
    width = settings.get_int("width");
    height = settings.get_int("height");    
    terminal_bgcolor = settings.get_string("bgcolor");
    terminal_fgcolor = settings.get_string("fgcolor");
    terminal_font = settings.get_string("font");
  }

  private void show_ui()
  {
    GLib.Pid child_pid;    
    
    term = new Vte.Terminal();
    term.set_encoding("UTF-8");
    term.set_scrollback_lines(4096);
    term.set_vexpand(true);
    term.set_hexpand(true);
    term.set_word_chars("-A-Za-z0-9,./?%&#_~:@+");
    term.child_exited.connect(term_exit_clicked);
    
    try
    {
      term.fork_command_full(Vte.PtyFlags.DEFAULT, GLib.Environment.get_current_dir(), { Vte.get_user_shell() }, null, SpawnFlags.SEARCH_PATH, null, out child_pid);
    }
    catch(Error e)
    {
      stderr.printf("error: %s\n", e.message);
    }

    var grid = new Gtk.Grid();
    var scrollbar = new Gtk.Scrollbar(Gtk.Orientation.VERTICAL, term.vadjustment);
    grid.attach(term, 0, 0, 1, 1);
    grid.attach(scrollbar, 1, 0, 1, 1);

    var notebook = new Gtk.Notebook();
    notebook.append_page(grid, null);
    notebook.set_show_tabs(false);
    
    var menuitem_preferences = new Gtk.MenuItem.with_label(_("Preferences"));
    menuitem_preferences.activate.connect(preferences_dialog);      
    
    var menuitem_about = new Gtk.MenuItem.with_label(_("About"));
    menuitem_about.activate.connect(about_dialog);
    
    var menu = new Gtk.Menu();
    menu.append(menuitem_preferences);
    menu.append(menuitem_about);
    menu.show_all();
    
    var menubutton = new Gtk.MenuButton();
    menubutton.valign = Gtk.Align.CENTER;
    menubutton.set_popup(menu);
    menubutton.set_image(new Gtk.Image.from_icon_name("emblem-system-symbolic", Gtk.IconSize.MENU));
    
    var headerbar = new Gtk.HeaderBar();
    headerbar.set_show_close_button(true);
    headerbar.set_title(NAME);
    headerbar.pack_end(menubutton);
    
    window = new Gtk.Window();
    window.set_default_size(width, height);
    window.set_titlebar(headerbar);
    window.add(notebook);
    window.set_icon_name(ICON);
    window.show_all();
    
    term_font_and_colors();
    term.grab_focus();
    
    context_menu = new Gtk.Menu();
    add_popup_menu(context_menu);
    window.delete_event.connect(() => { term_exit_clicked(); return true; });
  }

  private void set_color_from_string(string back, string text)
  {
    var bgcolor = Gdk.Color();
    var fgcolor = Gdk.Color();
    
    Gdk.Color.parse(back, out bgcolor);
    Gdk.Color.parse(text, out fgcolor);
    
    term.set_color_background(bgcolor);
    term.set_color_foreground(fgcolor);
  }
  
  private void term_font_and_colors()
  {
    term.set_cursor_blink_mode(Vte.TerminalCursorBlinkMode.OFF);
    term.set_cursor_shape(Vte.TerminalCursorShape.UNDERLINE);
    term.set_font_from_string(terminal_font);
    set_color_from_string(terminal_bgcolor, terminal_fgcolor);
  }
  
  // Preferences dialog - on font change (1)
  private void font_changed()
  {
    terminal_font = preferences_font_button.get_font().to_string();
    term.set_font_from_string(terminal_font);
    settings.set_string("font", terminal_font);
  }
  
  // Preferences dialog - on background change (2)
  private void bg_color_changed()
  {
    var color = preferences_bg_button.get_rgba();;
    int r = (int)Math.round(color.red * 255);
    int g = (int)Math.round(color.green * 255);
    int b = (int)Math.round(color.blue * 255);
    terminal_bgcolor = "#%02x%02x%02x".printf(r, g, b).up();
    set_color_from_string(terminal_bgcolor, terminal_fgcolor);
    settings.set_string("bgcolor", terminal_bgcolor);
  }
  
  // Preferences dialog - on foreground change (3)
  private void fg_color_changed()
  {
    var color = preferences_fg_button.get_rgba();;
    int r = (int)Math.round(color.red * 255);
    int g = (int)Math.round(color.green * 255);
    int b = (int)Math.round(color.blue * 255);
    terminal_fgcolor = "#%02x%02x%02x".printf(r, g, b).up();
    set_color_from_string(terminal_bgcolor, terminal_fgcolor);
    settings.set_string("fgcolor", terminal_fgcolor);
  }
  
  // Preferences dialog
  private void preferences_dialog()
  {
    preferences_font_label = new Gtk.Label(_("Font"));
    preferences_font_button = new Gtk.FontButton();
    preferences_font_button.font_name = term.get_font().to_string();
    preferences_font_button.font_set.connect(font_changed);

    var rgba_bgcolor = Gdk.RGBA();
    var rgba_fgcolor = Gdk.RGBA();
    rgba_bgcolor.parse(terminal_bgcolor);
    rgba_fgcolor.parse(terminal_fgcolor);
    
    preferences_bg_label = new Gtk.Label(_("Background"));
    preferences_bg_button = new Gtk.ColorButton.with_rgba(rgba_bgcolor);
    preferences_bg_button.color_set.connect(bg_color_changed);
    
    preferences_fg_label = new Gtk.Label(_("Foreground"));
    preferences_fg_button = new Gtk.ColorButton.with_rgba(rgba_fgcolor);
    preferences_fg_button.color_set.connect(fg_color_changed);
    
    var preferences_grid = new Gtk.Grid();
    preferences_grid.set_column_spacing(20);
    preferences_grid.set_row_spacing(10);
    preferences_grid.set_border_width(10);
    preferences_grid.set_row_homogeneous(true);
    preferences_grid.set_column_homogeneous(true);
    
    preferences_grid.attach(preferences_font_label, 0, 0, 1, 1);
    preferences_grid.attach(preferences_font_button, 1, 0, 1, 1);
    
    preferences_grid.attach(preferences_bg_label, 0, 1, 1, 1);
    preferences_grid.attach(preferences_bg_button, 1, 1, 1, 1);
      
    preferences_grid.attach(preferences_fg_label, 0, 2, 1, 1);
    preferences_grid.attach(preferences_fg_button, 1, 2, 1, 1);

    var preferences_headerbar = new Gtk.HeaderBar();
    preferences_headerbar.set_show_close_button(true);
    preferences_headerbar.set_title(_("Preferences"));
    
    preferences = new Gtk.Dialog();
    preferences.set_property("skip-taskbar-hint", true);
    preferences.set_transient_for(window);
    preferences.set_resizable(false);
    preferences.set_titlebar(preferences_headerbar);  
    
    var content = preferences.get_content_area() as Gtk.Container;
    content.add(preferences_grid);
    
    preferences.show_all();
  }
  
  // Context menu
  private void add_popup_menu(Gtk.Menu menu)
  {
    context_copy = new Gtk.MenuItem.with_label(_("Copy"));
    context_copy.activate.connect(() => { term.copy_clipboard(); });
    context_copy.show();
    context_menu.append(context_copy);
    
    context_paste = new Gtk.MenuItem.with_label(_("Paste"));
    context_paste.activate.connect(() => { term.paste_clipboard(); });
    context_paste.show();
    context_menu.append(context_paste);
    
    context_separator = new Gtk.SeparatorMenuItem();
    context_separator.show();
    context_menu.append(context_separator);
    
    context_select_all = new Gtk.MenuItem.with_label(_("Select all"));
    context_select_all.activate.connect(() => { term.select_all(); });
    context_select_all.show();
    context_menu.append(context_select_all);
    
    term.button_press_event.connect((event) =>
    {
      if (event.button == 3)
      {
        context_menu.select_first (false);
        context_menu.popup (null, null, null, event.button, event.time);
      }
      return false;
    });
  }

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

  private void term_exit_clicked()
  {
    window.get_size(out width, out height);
    settings.set_int("width", width);
    settings.set_int("height", height);
    GLib.Settings.sync();
    Gtk.main_quit();
  }
  
  private void execute_command(string command)
  {
    term.feed_child(command + "\n", command.length + 1);
  }

  // Start program
  private void run(string[] args)
  {
    if (args.length >= 2)
    {
      argument = args[1];
    }
    if (argument == "-e")
    {
      command = args[2];
      execute_command(command);
    }
  }

  private static int main(string[] args)
  {
    Gtk.init(ref args);
    var Taeni = new Program();
    Taeni.run(args);
    Gtk.main();
    return 0;    
  }
}
