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

private class Program : Gtk.Application
{
  const string NAME         = "Control Center";
  const string VERSION      = "1.1.0";
  const string DESCRIPTION  = _("Central place for accessing system configuration tools");
  const string ICON         = "control-center";
  const string[] AUTHORS = { "Simargl <archpup-at-gmail-dot-com>", "Efgee <efgee2003-at-yahoo-dot-com>", null };
  const int    MAX_ROW_APPS = 4; // max apps per row can be changed
 
  Gtk.Grid grid;
  Gtk.ApplicationWindow window;
  static int app_number;
  static int row_number;

  private const GLib.ActionEntry[] action_entries =
  {
    { "about", action_about },
    { "quit",  action_quit  }
  };

  private Program()
  {
    Object(application_id: "org.alphaos.control-center", flags: ApplicationFlags.FLAGS_NONE);
    add_action_entries(action_entries, this);
  }

  protected override void startup()
  {
    base.startup();

    var menu = new Menu();
    menu.append(_("About"),     "app.about");
    menu.append(_("Quit"),      "app.quit");

    set_app_menu(menu);

    // Grid
    grid = new Gtk.Grid();
    grid.set_column_spacing(25);
    grid.set_column_homogeneous(true);

    app_number = 0;
    row_number = 0;
   
    create_group(_("<b>Personal</b>"));
    create_entry(_("Wallpaper"),       "wpset",               "preferences-desktop-wallpaper", _("Change your desktop wallpaper"));
    create_entry(_("Appearance"),      "lxappearance",        "preferences-desktop-theme",     _("Customize Look and Feel"));
    create_entry(_("Openbox"),         "obconf",              "obconf",                        _("Tweak settings for Openbox"));
    create_entry(_("Menu Editor"),     "kickshaw",            "menu-editor",                   _("Kickshaw is a menu editor for Openbox"));

    create_group(_("<b>Hardware</b>"));
    create_entry(_("Display"),         "lxrandr",             "lxrandr",                       _("Change screen resolution and configure external monitors"));
    create_entry(_("Input Devices"),   "lxinput",             "lxinput",                       _("Configure keyboard, mouse, and other input devices"));
    create_entry(_("Network"),         "connman-ui-gtk",      "gnome-nettool",                 _("A full-featured GTK based trayicon UI for ConnMan"));

    create_group(_("<b>System</b>"));
    create_entry(_("Task Manager"),    "lxtask",              "utilities-system-monitor",      _("Manage running processes"));
    create_entry(_("Setup Savefile"),  "makepfile.sh",        "application-x-fs4",             _("Savefile creator for alphaOS"));
    create_entry(_("Grub4DOS"),        "grub4dos-ui",         "grub4dos-ui",                   _("Configure Grub4DOS bootup loader"));

    var headerbar = new Gtk.HeaderBar();
    headerbar.set_show_close_button(true);
    headerbar.set_title(NAME);

    window = new Gtk.ApplicationWindow(this);
    window.window_position = Gtk.WindowPosition.CENTER;
    window.set_titlebar(headerbar);
    window.add(grid);
    window.set_resizable(false);
    window.set_border_width(10);
    window.set_icon_name(ICON);
    window.show_all();
  }

  public override void activate()
  {
    window.present();
  }
 
  // Creates new group - argument: label
  private void create_group(string label)
  {
    var group_name = new Gtk.Label(label);
    group_name.set_use_markup(true);
    group_name.set_alignment(0, 1);
   
    if (row_number != 0)
    {
      group_name.height_request = 50;
    }
   
    app_number = 0;
    row_number = row_number + 2;
    grid.attach(group_name, app_number, row_number, 1, 1);
   
    row_number = row_number + 1;
  }

  // Creates new entry - arguments: label, appname, icon, tooltip
  private void create_entry(string label, string appname, string icon, string tooltip)
  {
    if (app_number == MAX_ROW_APPS)
    {
      app_number = 0;
      row_number = row_number + 2;
    }
   
    var entry_image = new Gtk.Image.from_icon_name(icon, Gtk.IconSize.DND);
    entry_image.set_pixel_size(73);
   
    var entry_button = new Gtk.Button();
    entry_button.set_image(entry_image);
    entry_button.set_tooltip_text(tooltip);
    entry_button.clicked.connect(() => { button_item_clicked(appname); });
    set_button_size_relief_focus(entry_button);
    grid.attach(entry_button, app_number, row_number, 1, 1);
   
    var entry_label = new Gtk.Label(label);
    grid.attach(entry_label, app_number, (row_number + 1), 1, 1);
   
    app_number++;
  }

  private void button_item_clicked(string item_name)
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
 
  private void set_button_size_relief_focus(Gtk.Button button_name)
  {
    button_name.set_relief(Gtk.ReliefStyle.NONE);
    button_name.height_request = 86;
    button_name.set_always_show_image(true);
    button_name.set_image_position(Gtk.PositionType.TOP);
    button_name.set_can_focus(false);
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
