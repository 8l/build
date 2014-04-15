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

private class Program : Gtk.Application
{
  const string NAME        = "Taeni";
  const string VERSION     = "1.7.0";
  const string DESCRIPTION = _("Terminal emulator based on GTK+ and VTE");
  const string ICON        = "utilities-terminal";
  const string APP_ID      = "org.alphaos.taeni";
  const string APP_ID_PREF = "org.alphaos.taeni.preferences";  
  const string[] AUTHORS   = { "Simargl <archpup-at-gmail-dot-com>", null };
  
  Vte.Terminal term;
  Gtk.Dialog preferences;
  Gtk.Menu context_menu;
  Gtk.ApplicationWindow window;
  Gtk.Notebook notebook;
  
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
  GLib.Pid child_pid;

  private const GLib.ActionEntry[] action_entries =
  {
    { "pref",  action_pref  },
    { "about", action_about },
    { "quit",  action_quit  }
  };

  private Program()
  {
    Object(application_id: APP_ID, flags: ApplicationFlags.HANDLES_COMMAND_LINE);
    add_action_entries(action_entries, this);
  }
  
  public override void startup()
  {
    base.startup();

    var menu = new Menu();
    
    var section = new Menu();
    section.append(_("Preferences"), "app.pref");
    menu.append_section (null, section);

    section = new Menu();
    section.append(_("About"), "app.about");
    section.append(_("Quit"), "app.quit");
    menu.append_section (null, section);

    set_app_menu(menu);
    
    settings = new GLib.Settings(APP_ID_PREF);
    width = settings.get_int("width");
    height = settings.get_int("height");
    terminal_bgcolor = settings.get_string("bgcolor");
    terminal_fgcolor = settings.get_string("fgcolor");
    terminal_font = settings.get_string("font");

    var gear_menu = new Gtk.Menu();
    add_popup_menu(gear_menu);
    gear_menu.show_all();
    
    var menubutton = new Gtk.MenuButton();
    menubutton.valign = Gtk.Align.CENTER;
    menubutton.set_popup(gear_menu);
    menubutton.set_image(new Gtk.Image.from_icon_name("emblem-system-symbolic", Gtk.IconSize.MENU));

    var headerbar = new Gtk.HeaderBar();
    headerbar.set_show_close_button(true);
    headerbar.set_title(NAME);
    headerbar.pack_end(menubutton);

    notebook = new Gtk.Notebook();
    notebook.expand = true;
    notebook.set_scrollable(true);

    var grid = new Gtk.Grid();
    grid.attach(notebook, 0, 1, 1, 1);

    window = new Gtk.ApplicationWindow(this);
    window.set_default_size(width, height);
    window.set_titlebar(headerbar);
    window.add(grid);
    window.set_icon_name(ICON);
    window.show_all();
    window.delete_event.connect(() => { action_quit(); return true; });

    context_menu = new Gtk.Menu();
    add_popup_menu(context_menu);
  }

  public override void activate() 
  {
    window.present();
  }
  
  public override int command_line(ApplicationCommandLine command_line)
  {
    var args = command_line.get_arguments();
    argument = args[1];
    string path = "";
    if (argument == "-d")
    {
      path = args[2];
    }
    create_tab(path);
    window.present();
    if (argument == "-e")
    {
      command = args[2];
      execute_command(command);
    }
    return 0;
  }

  private void execute_command(string command)
  {
    term.feed_child(command + "\n", command.length + 1);
  }

  private void create_tab(string path)
  {
    term = new Vte.Terminal();
    term.set_encoding("UTF-8");
    term.set_scrollback_lines(4096);
    term.set_vexpand(true);
    term.set_hexpand(true);
    term.set_word_chars("-A-Za-z0-9,./?%&#_~:@+");
    term.child_exited.connect(action_quit);
    term.button_press_event.connect(terminal_button_press);
    
    try
    {
      term.fork_command_full(Vte.PtyFlags.DEFAULT, path, { Vte.get_user_shell() }, null, SpawnFlags.SEARCH_PATH, null, out child_pid);
    }
    catch(Error e)
    {
      stderr.printf("error: %s\n", e.message);
    }
    
    var scrollbar = new Gtk.Scrollbar(Gtk.Orientation.VERTICAL, term.vadjustment);
    
    var grid = new Gtk.Grid();
    grid.attach(term, 0, 0, 1, 1);
    grid.attach(scrollbar, 1, 0, 1, 1);
    grid.show_all();

    notebook.append_page(grid, null);
    notebook.show_all();
    notebook.set_current_page(notebook.get_n_pages() - 1);
    notebook.set_show_tabs(true);
    if (notebook.get_n_pages() == 1)
    {
      notebook.set_show_tabs(false);
    }
    
    term.set_cursor_blink_mode(Vte.TerminalCursorBlinkMode.OFF);
    term.set_cursor_shape(Vte.TerminalCursorShape.UNDERLINE);
    term.set_font_from_string(terminal_font);
    term.grab_focus();
    set_color_from_string(terminal_bgcolor, terminal_fgcolor);
  }

  // Context menu
  private void add_popup_menu(Gtk.Menu menu)
  {
    var context_new = new Gtk.MenuItem.with_label(_("New tab"));
    context_new.activate.connect(() => { create_tab(""); });

    var context_separator1 = new Gtk.SeparatorMenuItem();

    var context_copy = new Gtk.MenuItem.with_label(_("Copy"));
    context_copy.activate.connect(() => { get_current_terminal(); term.copy_clipboard(); });

    var context_paste = new Gtk.MenuItem.with_label(_("Paste"));
    context_paste.activate.connect(() => { get_current_terminal(); term.paste_clipboard(); });

    var context_separator2 = new Gtk.SeparatorMenuItem();

    var context_select_all = new Gtk.MenuItem.with_label(_("Select all"));
    context_select_all.activate.connect(() => { get_current_terminal(); term.select_all(); });

    menu.append(context_new);
    menu.append(context_separator1);
    menu.append(context_copy);
    menu.append(context_paste);
    menu.append(context_separator2);
    menu.append(context_select_all);
    menu.show_all();
  }

  private bool terminal_button_press(Gdk.EventButton event)
  {
    if (event.button == 3)
    {
      context_menu.select_first (false);
      context_menu.popup (null, null, null, event.button, event.time);
    }
    return false;
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

  private Vte.Terminal get_current_terminal()
  {
    var grid = (Gtk.Grid) notebook.get_nth_page(notebook.get_current_page());
    term = (Vte.Terminal) grid.get_child_at(0, 0);
    return term;
  }

  // Preferences dialog - on font change (1)
  private void font_changed()
  {
    terminal_font = preferences_font_button.get_font().to_string();
    for (int i = 0; i < notebook.get_n_pages(); i++)
    {
      var grid = (Gtk.Grid) notebook.get_nth_page(i);
      term = (Vte.Terminal) grid.get_child_at(0, 0);
      term.set_font_from_string(terminal_font);
    }
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
    for (int i = 0; i < notebook.get_n_pages(); i++)
    {
      var grid = (Gtk.Grid) notebook.get_nth_page(i);
      term = (Vte.Terminal) grid.get_child_at(0, 0);
      set_color_from_string(terminal_bgcolor, terminal_fgcolor);
    }
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
    for (int i = 0; i < notebook.get_n_pages(); i++)
    {
      var grid = (Gtk.Grid) notebook.get_nth_page(i);
      term = (Vte.Terminal) grid.get_child_at(0, 0);
      set_color_from_string(terminal_bgcolor, terminal_fgcolor);
    }
    settings.set_string("fgcolor", terminal_fgcolor);
  }
  
  // Preferences dialog
  private void action_pref()
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

  private void action_about()
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

  private void save_settings()
  {
    window.get_size(out width, out height);
    settings.set_int("width", width);
    settings.set_int("height", height);
    GLib.Settings.sync();
  }
  
  private void action_quit()
  {
    save_settings();
    this.quit();
  }

  private static int main (string[] args)
  {
    Program app = new Program();
    return app.run(args);
  }
}
