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

using LibmpControl;

private class Program : GLib.Object
{
  const string NAME = "Simple Radio";
  const string VERSION = "1.8.0";
  const string DESCRIPTION = _("Play radio streams with mpv");
  const string ICON = "simple-radio-play";
  const string[] AUTHORS = { "Simargl <archpup-at-gmail-dot-com>", null };
  
  Gtk.StatusIcon simple_radio;
  Gtk.Menu menutray;
  Gtk.MenuItem menuitem_stop;
  Gtk.Grid configure_grid;
  Gtk.Dialog configure;
  
  GLib.Settings settings;
  bool menuitem_stop_sensitive;
  int level;
  
  string FIFO;
  string OUTPUT;
  
  string[] radio01;
  string[] radio02;
  string[] radio03;
  string[] radio04;
  string[] radio05;
  string[] radio06;
  string[] radio07;
  string[] radio08;
  string[] radio09;  
  string[] radio10;
  string[] radio11;  
  string[] radio12;  
  string[] radio13;  
  string[] radio14;
  string[] radio15;
  
  private Program()
  {
    string random_number = GLib.Random.int_range(1000, 5000).to_string();
    FIFO = "/tmp/simple_radio_fifo_" + random_number;
    OUTPUT = "/tmp/simple_radio_output_" + random_number;    
    level = 100;
    
    load_settings();

    simple_radio = new Gtk.StatusIcon();
    simple_radio.set_tooltip_text("Simple Radio");
    simple_radio.set_visible(true);
    simple_radio.popup_menu.connect(menutray_popup);
    simple_radio.activate.connect(send_notification);
    simple_radio.scroll_event.connect(volume_level_change_on_scroll);
    
    update_tray_icon("simple-radio-stop");
    create_menutray();
    start_notifications();
  }
  
  private void load_settings()
  {
    settings = new GLib.Settings("org.alphaos.simple-radio.preferences");
    radio01 = settings.get_strv("radio01");
    radio02 = settings.get_strv("radio02");
    radio03 = settings.get_strv("radio03");
    radio04 = settings.get_strv("radio04");
    radio05 = settings.get_strv("radio05");
    radio06 = settings.get_strv("radio06");
    radio07 = settings.get_strv("radio07");
    radio08 = settings.get_strv("radio08");
    radio09 = settings.get_strv("radio09");
    radio10 = settings.get_strv("radio10");
    radio11 = settings.get_strv("radio11");
    radio12 = settings.get_strv("radio12");
    radio13 = settings.get_strv("radio13");
    radio14 = settings.get_strv("radio14");
    radio15 = settings.get_strv("radio15");
  }
  
  private void radio_exit()
  {
    mpv_stop_playback(FIFO, OUTPUT);
    update_tray_icon("simple-radio-stop");
    menuitem_stop_sensitive = false;
    menuitem_stop.set_sensitive(menuitem_stop_sensitive);
  } 

  private void update_tray_icon(string icon_name)
  {
    simple_radio.set_from_icon_name(icon_name);
  }

  private void send_notification()
  {
    try
    {
      Process.spawn_command_line_async("simple-radio-notify send");
    }
    catch (GLib.Error e)
    {
      stderr.printf ("%s\n", e.message);
    }
  }

  private void start_notifications()
  {
    try
    {
      Process.spawn_command_line_async("simple-radio-notify start");
    }
    catch (GLib.Error e)
    {
      stderr.printf ("%s\n", e.message);
    }
  }

  private void play_radio_menuitem_clicked(string address)
  {
    mpv_stop_playback(FIFO, OUTPUT);
    mpv_audio_with_volume_level(level.to_string(), FIFO, address, OUTPUT);
    update_tray_icon("simple-radio-play");
    menuitem_stop_sensitive = true;
    menuitem_stop.set_sensitive(menuitem_stop_sensitive);
  }
  
  private void create_menutray()
  {
    menutray = new Gtk.Menu();

    add_radio_menuitem(radio01[0], radio01[1]);
    add_radio_menuitem(radio02[0], radio02[1]);
    add_radio_menuitem(radio03[0], radio03[1]);
    add_radio_menuitem(radio04[0], radio04[1]);
    add_radio_menuitem(radio05[0], radio05[1]);
    add_radio_menuitem(radio06[0], radio06[1]);
    add_radio_menuitem(radio07[0], radio07[1]);
    add_radio_menuitem(radio08[0], radio08[1]);
    add_radio_menuitem(radio09[0], radio09[1]);
    add_radio_menuitem(radio10[0], radio10[1]);
    add_radio_menuitem(radio11[0], radio11[1]);
    add_radio_menuitem(radio12[0], radio12[1]);
    add_radio_menuitem(radio13[0], radio13[1]);
    add_radio_menuitem(radio14[0], radio14[1]);
    add_radio_menuitem(radio15[0], radio15[1]);
    
    var separator1 = new Gtk.SeparatorMenuItem();
    var separator2 = new Gtk.SeparatorMenuItem();
    
    menuitem_stop = new Gtk.MenuItem.with_label(_("Turn Off"));
    menuitem_stop.set_sensitive(menuitem_stop_sensitive);
    menuitem_stop.override_font(Pango.FontDescription.from_string("Oxygen 11"));
    menuitem_stop.activate.connect(radio_exit);

    var menuitem_configure = new Gtk.MenuItem.with_label(_("Edit list"));
    menuitem_configure.override_font(Pango.FontDescription.from_string("Oxygen 11"));
    menuitem_configure.activate.connect(configure_dialog);

    var menuitem_about = new Gtk.MenuItem.with_label(_("About"));
    menuitem_about.override_font(Pango.FontDescription.from_string("Oxygen 11"));
    menuitem_about.activate.connect(action_about);
    
    var menuitem_quit = new Gtk.MenuItem.with_label(_("Quit"));
    menuitem_quit.override_font(Pango.FontDescription.from_string("Oxygen 11"));
    menuitem_quit.activate.connect(() => { radio_exit(); Gtk.main_quit(); });      
    
    menutray.append(separator1);
    menutray.append(menuitem_stop);
    menutray.append(menuitem_configure); 
    menutray.append(separator2);
    menutray.append(menuitem_about);
    menutray.append(menuitem_quit);
    menutray.show_all();
  }
  
  private void add_radio_menuitem(string radio, string address)
  {
    if (radio != "")
    {
      var menuitem = new Gtk.MenuItem();
      menuitem.set_label(radio);
      menuitem.override_font(Pango.FontDescription.from_string("Oxygen 11"));
      menuitem.activate.connect(() => { play_radio_menuitem_clicked(address); });      
      menutray.append(menuitem);
    }
  }

  private void menutray_popup(uint button, uint time)
  {
    menutray.popup(null, null, null, button, time);
  }
  
  private void configure_dialog()
  {
    configure_grid = new Gtk.Grid();
    configure_grid.set_row_spacing(5);
    configure_grid.set_column_spacing(10);
    configure_grid.set_border_width(5);
    configure_grid.set_row_homogeneous(true);
    configure_grid.set_column_homogeneous(true);
    
    configure_dialog_add_entry(radio01[0], radio01[1], "radio01", radio01,  1);
    configure_dialog_add_entry(radio02[0], radio02[1], "radio02", radio02,  2);
    configure_dialog_add_entry(radio03[0], radio03[1], "radio03", radio03,  3);
    configure_dialog_add_entry(radio04[0], radio04[1], "radio04", radio04,  4);
    configure_dialog_add_entry(radio05[0], radio05[1], "radio05", radio05,  5);
    configure_dialog_add_entry(radio06[0], radio06[1], "radio06", radio06,  6);
    configure_dialog_add_entry(radio07[0], radio07[1], "radio07", radio07,  7);
    configure_dialog_add_entry(radio08[0], radio08[1], "radio08", radio08,  8);
    configure_dialog_add_entry(radio09[0], radio09[1], "radio09", radio09,  9);
    configure_dialog_add_entry(radio10[0], radio10[1], "radio10", radio10, 10);
    configure_dialog_add_entry(radio11[0], radio11[1], "radio11", radio11, 11);    
    configure_dialog_add_entry(radio12[0], radio12[1], "radio12", radio12, 12);    
    configure_dialog_add_entry(radio13[0], radio13[1], "radio13", radio13, 13);    
    configure_dialog_add_entry(radio14[0], radio14[1], "radio14", radio14, 14);
    configure_dialog_add_entry(radio15[0], radio15[1], "radio15", radio15, 15);

    var scrolled_window = new Gtk.ScrolledWindow(null, null);
    scrolled_window.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.ALWAYS);
    scrolled_window.set_size_request(550, 280);
    scrolled_window.expand = true;
    scrolled_window.add(configure_grid);

    var configure_headerbar = new Gtk.HeaderBar();
    configure_headerbar.set_show_close_button(true);
    configure_headerbar.set_title(_("Edit list"));
    
    configure = new Gtk.Dialog();
    configure.set_resizable(false);
    configure.set_icon_name(ICON);
    configure.set_titlebar(configure_headerbar);
    
    var content = configure.get_content_area() as Gtk.Container;
    content.add(scrolled_window);
    
    configure.show_all();
  }

  private void configure_dialog_add_entry(string radio, string address, string save_label, string[] save, int row)
  {
    var entry_name = new Gtk.Entry();
    var entry_address = new Gtk.Entry();
    entry_name.set_text(radio);
    entry_address.set_text(address);  
    entry_name.changed.connect(() => 
    {
      save[0] = entry_name.get_text();
      settings.set_strv(save_label, save); 
    });
    entry_address.changed.connect(() => 
    {
      save[1] = entry_address.get_text();
      settings.set_strv(save_label, save); 
    });
    configure_grid.attach(entry_name,    0, row, 1, 1);
    configure_grid.attach(entry_address, 1, row, 2, 1);
  }

  private bool volume_level_change_on_scroll(Gdk.EventScroll event)
  {
    if (event.direction == Gdk.ScrollDirection.UP)
    { 
      if (level < 100)
      {
        level = level + 10;
      }
    }
    if (event.direction == Gdk.ScrollDirection.DOWN)
    {
      if (level > 0)
      {
        level = level - 10;
      }
    }
    print("%s\n".printf(level.to_string()));
    mpv_send_command(FIFO, "no-osd set volume %s".printf(level.to_string()));
    return true;
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
    about.license_type = Gtk.License.GPL_3_0;
    about.run();
    about.hide();
  }
  
  public static int main (string[] args)
  {
    Gtk.init(ref args);
    new Program();
    Gtk.main();
    return 0;
  }
}
