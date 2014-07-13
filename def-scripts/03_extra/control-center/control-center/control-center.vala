/*  Copyright (c) alphaOS
 *  Written by simargl <archpup-at-gmail-dot-com>
 *  Modified by efgee <efgee2003-at-yahoo-dot-com>
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

private class Program: Gtk.Application
{
  const string NAME        = _("Control Center");
  const string VERSION     =   "1.5.0";
  const string DESCRIPTION = _("Central place for accessing system configuration tools");
  const string ICON        =   "control-center";
  const string[] AUTHORS   = { "Simargl <archpup-at-gmail-dot-com>", "Efgee <efgee2003-at-yahoo-dot-com>", null };

  GLib.Settings settings;
  Gtk.ApplicationWindow window;
  Gtk.Grid grid;
  Gtk.IconView view;
  Gtk.ListStore model;
  Gtk.Revealer revealer_one;
  Gtk.Revealer revealer_two;
  Gtk.ScrolledWindow scrolled;
  Gtk.ToggleButton button_next;
  Gtk.TreeIter iter;

  private const GLib.ActionEntry[] action_entries =
  {   
    { "about", action_about },
    { "quit",  action_quit  }
  };

  public Program()
  {
    Object(application_id: "org.alphaos.control-center", flags: ApplicationFlags.FLAGS_NONE);
    add_action_entries(action_entries, this);
  }

  public override void startup()
  {
    base.startup();

    var menu = new Menu();
    menu.append(_("About"), "app.about");
    menu.append(_("Quit"),  "app.quit");

    set_app_menu(menu);
    
    add_accelerator("<Control>Q", "app.quit", null);

    settings = new GLib.Settings("org.alphaos.control-center.preferences");

    button_next = new Gtk.ToggleButton.with_label(_("Next"));
    button_next.valign = Gtk.Align.CENTER;
    button_next.set_active(false);
    button_next.toggled.connect(action_reveal_list);

    model = new Gtk.ListStore(4, typeof (Gdk.Pixbuf), typeof (string), typeof (string), typeof (string));

    view = new Gtk.IconView.with_model(model);
    view.set_pixbuf_column(0);
    view.set_text_column(1);
    view.set_tooltip_column(3);
    view.set_column_spacing(3);
    view.set_item_width(82);
    view.set_activate_on_single_click(true);
    view.item_activated.connect(icon_clicked);

    scrolled = new Gtk.ScrolledWindow(null, null);
    scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
    scrolled.add(view);

    add_iconview_item(_("Wallpaper"),      "wpset",          "preferences-desktop-wallpaper", _("Change your desktop wallpaper"));
    add_iconview_item(_("Appearance"),     "lxappearance",   "preferences-desktop-theme",     _("Customize Look and Feel"));
    add_iconview_item(_("Openbox"),        "obconf",         "preferences-system-windows",    _("Tweak settings for Openbox"));
    add_iconview_item(_("Menu Editor"),    "kickshaw",       "menu-editor",                   _("Kickshaw is a menu editor for Openbox"));

    add_iconview_item(_("Display"),        "lxrandr",        "preferences-desktop-display",   _("Change screen resolution and configure external monitors"));
    add_iconview_item(_("Input Devices"),  "lxinput",        "preferences-desktop-keyboard",  _("Configure keyboard, mouse, and other input devices"));
    add_iconview_item(_("Network"),        "connman-ui-gtk", "preferences-system-network",    _("A full-featured GTK based trayicon UI for ConnMan"));
    add_iconview_item(_("Task Manager"),   "lxtask",         "utilities-system-monitor",      _("Manage running processes"));

    add_iconview_item(_("Setup Savefile"), "makepfile.sh",   "application-x-fs4",             _("Savefile creator for alphaOS"));
    add_iconview_item(_("Installer"),      "alphainst.sh",   "drive-harddisk",                _("Install the system and/or configure Grub2 boot loader"));

    grid = new Gtk.Grid();
    grid.get_style_context().add_class(Gtk.STYLE_CLASS_VIEW);
    grid.set_column_homogeneous(true);
    grid.set_column_spacing(10);
    grid.set_row_spacing(10);

    add_combo_boxes();

    revealer_one = new Gtk.Revealer();
    revealer_one.add(scrolled);
    revealer_one.set_transition_type(Gtk.RevealerTransitionType.SLIDE_LEFT);
    revealer_one.set_reveal_child(true);
    revealer_one.expand = true;

    revealer_two = new Gtk.Revealer();
    revealer_two.add(grid);
    revealer_two.set_transition_type(Gtk.RevealerTransitionType.SLIDE_RIGHT);
    revealer_two.set_reveal_child(false);
    revealer_two.expand = false;

    var main_grid = new Gtk.Grid();
    main_grid.attach(revealer_one, 0, 0, 1, 1);
    main_grid.attach(revealer_two, 1, 0, 1, 1);

    var headerbar = new Gtk.HeaderBar();
    headerbar.pack_start(button_next);
    headerbar.set_show_close_button(true);
    headerbar.set_title(NAME);

    window = new Gtk.ApplicationWindow(this);
    window.window_position = Gtk.WindowPosition.CENTER;
    window.add(main_grid);
    window.set_icon_name(ICON);
    window.set_titlebar(headerbar);
    window.set_default_size(550, 420);
    window.show_all();
  }

  public override void activate()
  {
    window.present();
  }

  private void add_iconview_item(string name, string command, string icon, string tooltip)
  {
    var icon_theme = Gtk.IconTheme.get_default();
    try
    {
      model.append(out iter);
      Gdk.Pixbuf pixbuf = icon_theme.load_icon(icon, 70, 0);
      model.set(iter, 0, pixbuf, 1, name, 2, command, 3, tooltip);
    }
    catch (GLib.Error e)
    {
      stderr.printf ("%s\n", e.message);
    }
  }

  private void icon_clicked()
  {
    List<Gtk.TreePath> paths = view.get_selected_items();
    GLib.Value exec;
    foreach (Gtk.TreePath path in paths)
    {
      model.get_iter(out iter, path);
      model.get_value(iter, 2, out exec);
      execute_command((string)exec);
    }
  }
  
  private void execute_command(string item_name)
  {
    try
    {
      Process.spawn_command_line_async(item_name);
    }
    catch (GLib.Error e)
    {
      stderr.printf ("%s\n", e.message);
    }
  }

  private void add_combo_boxes()
  {
    // conky
    var clabel = new Gtk.Label(_("Conky theme"));
    var cbox = new Gtk.ComboBoxText();
    cbox.append("simplyx", "SimplyX");
    cbox.append("classic", "Classic");
    cbox.append("cubes",   "Cubes");
    cbox.append("gotham",  "Gotham");
    cbox.set_active_id(settings.get_string("conky-theme"));

    // tint2
    var tlabel = new Gtk.Label(_("Tint2 theme"));
    var tbox = new Gtk.ComboBoxText();
    tbox.append("crunchbang",   "Crunchbang");
    tbox.append("default",      "Default");
    tbox.append("gaia",         "Gaia");
    tbox.append("left_sidebar", "Left Sidebar");
    tbox.append("numix",        "Numix");
    tbox.append("numix_left",   "Numix Left");
    tbox.append("numix_text",     "Numix Text");
    tbox.set_active_id(settings.get_string("tint2-theme"));

    // notify-osd
    var notify_settings = new GLib.Settings("com.canonical.notify-osd");
    var nlabel = new Gtk.Label(_("Notifications"));
    var nbox = new Gtk.ComboBoxText();
    nbox.append("1", "Top right corner");
    nbox.append("2", "Middle right");
    nbox.append("3", "Bottom right corner");
    nbox.set_active_id(notify_settings.get_int("gravity").to_string());

    // attach
    grid.attach(clabel, 0, 0, 1, 1);
    grid.attach(cbox,   1, 0, 1, 1);
    grid.attach(tlabel, 0, 1, 1, 1);
    grid.attach(tbox,   1, 1, 1, 1);
    grid.attach(nlabel, 0, 2, 1, 1);
    grid.attach(nbox,   1, 2, 1, 1);

    // signal changed connect
    cbox.changed.connect(() => { execute_command("desktop-ctrl conky theme %s\n".printf(cbox.get_active_id())); settings.set_string("conky-theme", cbox.get_active_id());});
    tbox.changed.connect(() => { execute_command("desktop-ctrl tint2 theme %s\n".printf(tbox.get_active_id())); settings.set_string("tint2-theme", tbox.get_active_id());});
    nbox.changed.connect(() => { notify_settings.set_int("gravity", int.parse(nbox.get_active_id())); GLib.Settings.sync(); execute_command("notify-send -t 1500 -i dialog-information-symbolic 'Test' 'This is a test notification'"); });
  }

  private void action_reveal_list()
  {
    if (button_next.get_active() == true)
    {
      revealer_two.set_reveal_child(true);
      revealer_one.set_reveal_child(false);
      revealer_one.expand = false;
      revealer_two.expand = true;
      button_next.set_label(_("Back"));
    }
    else
    {
      revealer_one.set_reveal_child(true);
      revealer_two.set_reveal_child(false);
      revealer_one.expand = true;
      revealer_two.expand = false;
      button_next.set_label(_("Next"));
    }
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

  private void action_quit()
  {
    quit();
  }

  private static int main (string[] args)
  {
    Program app = new Program();
    return app.run(args);
  }
}
