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

private class Program : Gtk.Application
{
  const string NAME = "PlayTV";
  const string VERSION = "1.0.5";
  const string DESCRIPTION = _("GTK3 based interface for watching online TV channels");
  const string ICON = "playtv";
  const string[] AUTHORS = { "Simargl <archpup-at-gmail-dot-com>", null };

  Gtk.ApplicationWindow window;
  Gtk.Dialog configure;
  Gtk.DrawingArea drawing_area;
  Gtk.Grid configure_grid;
  Gtk.HeaderBar headerbar;
  Gtk.ListStore liststore;
  Gtk.MenuButton menubutton;
  Gtk.Revealer revealer;
  Gtk.ScrolledWindow scrolled;
  Gtk.ToggleButton button_list;
  Gtk.TreeView treeview;
  GLib.Settings settings;

  string[] tv01;
  string[] tv02;
  string[] tv03;
  string[] tv04;
  string[] tv05;
  string[] tv06;
  string[] tv07;
  string[] tv08;
  string[] tv09;  
  string[] tv10;
  string[] tv11;  
  string[] tv12;  
  string[] tv13;  
  string[] tv14;
  string[] tv15;
  string[] tv16;
  string[] tv17;  
  string[] tv18;  
  string[] tv19;  
  string[] tv20;

  string video_mode;
  string FIFO;
  string OUTPUT;
  long xid;

  private const GLib.ActionEntry[] action_entries =
  {
    { "edit-list",          action_edit_list          },
    { "full-screen-toggle", action_full_screen_toggle },
    { "full-screen-exit",   action_full_screen_exit   },
    { "pause",              action_pause              },
    { "show-menu",          action_show_menu          },
    { "about",              action_about              },
    { "quit",               action_quit               }
  };

  private Program()
  {
    Object(application_id: "org.alphaos.playtv", flags: ApplicationFlags.FLAGS_NONE);
    add_action_entries(action_entries, this);
  }
  
  public override void startup()
  {
    base.startup();

    var menu = new Menu();
    menu.append(_("About"),     "app.about");
    menu.append(_("Quit"),      "app.quit");

    set_app_menu(menu);
    
    add_accelerator("F10", "app.show-menu", null);
    add_accelerator("F11", "app.full-screen-toggle", null);
    add_accelerator("space", "app.pause", null);
    add_accelerator("Escape", "app.full-screen-exit", null);
    add_accelerator("<Control>Q", "app.quit", null);

    string random_number = GLib.Random.int_range(1000, 5000).to_string();
    FIFO = "/tmp/tvplay_fifo_" + random_number;
    OUTPUT = "/tmp/tvplay_output_" + random_number;    
    
    drawing_area = new Gtk.DrawingArea();
    drawing_area.set_size_request(500, 410);
    drawing_area.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
    drawing_area.button_press_event.connect(mouse_button_press_events);    
    drawing_area.set_vexpand(true);
    drawing_area.set_hexpand(true);
    
    var cell = new Gtk.CellRendererText();
    liststore = new Gtk.ListStore(4, typeof (string), typeof (string), typeof (string), typeof (string));
    cell.set("font", "Cantarell 10");
    
    treeview = new Gtk.TreeView();
    treeview.set_model(liststore);
    treeview.row_activated.connect(play_selected);
    treeview.insert_column_with_attributes (-1, _("Name"), cell, "text", 0);
    treeview.insert_column_with_attributes (-1, _("Genre"), cell, "text", 1);
    treeview.insert_column_with_attributes (-1, _("Country"), cell, "text", 2);
    
    load_settings();   
    load_liststore_items();

    // Buttons
    button_list = new Gtk.ToggleButton();
    button_list.valign = Gtk.Align.CENTER;
    button_list.set_image(new Gtk.Image.from_icon_name("view-list-symbolic", Gtk.IconSize.MENU));
    button_list.set_active(true);
    button_list.toggled.connect(action_reveal_list);

    scrolled = new Gtk.ScrolledWindow(null, null);
    scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.ALWAYS);
    scrolled.set_size_request(230, 410);
    scrolled.add(treeview);
 
    revealer = new Gtk.Revealer();
    revealer.add(scrolled);
    revealer.set_transition_duration(300);
    revealer.set_reveal_child(true);
    revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_LEFT);
    
    var grid = new Gtk.Grid();
    grid.attach(revealer,     0, 0, 1, 1);
    grid.attach(drawing_area, 1, 0, 1, 1);

    var gear_menu = new Menu();
    gear_menu.append(_("Edit list"), "app.edit-list");

    menubutton = new Gtk.MenuButton();
    menubutton.valign = Gtk.Align.CENTER;
    menubutton.set_use_popover(true);
    menubutton.set_menu_model(gear_menu);
    menubutton.set_image(new Gtk.Image.from_icon_name("emblem-system-symbolic", Gtk.IconSize.MENU));

    headerbar = new Gtk.HeaderBar();
    headerbar.set_show_close_button(true);
    headerbar.set_title(NAME);
    headerbar.pack_start(button_list);
    headerbar.pack_end(menubutton);
    
    window = new Gtk.ApplicationWindow(this);
    window.set_icon_name(ICON);
    window.set_titlebar(headerbar);
    window.set_default_size(790, 410);
    window.add(grid);
    window.show_all();
    window.delete_event.connect(() => { action_quit(); return true; });
    
    var drawing_area_window = (Gdk.X11.Window)drawing_area.get_window();
    xid = (long)drawing_area_window.get_xid();
  }

  public override void activate()
  {
    window.present();
  }
  
  private void load_settings()
  {
    settings = new GLib.Settings("org.alphaos.playtv.preferences");
    video_mode = settings.get_string("video-mode");
    tv01 = settings.get_strv("tv01");
    tv02 = settings.get_strv("tv02");
    tv03 = settings.get_strv("tv03");
    tv04 = settings.get_strv("tv04");
    tv05 = settings.get_strv("tv05");
    tv06 = settings.get_strv("tv06");
    tv07 = settings.get_strv("tv07");
    tv08 = settings.get_strv("tv08");
    tv09 = settings.get_strv("tv09");
    tv10 = settings.get_strv("tv10");
    tv11 = settings.get_strv("tv11");
    tv12 = settings.get_strv("tv12");
    tv13 = settings.get_strv("tv13");
    tv14 = settings.get_strv("tv14");
    tv15 = settings.get_strv("tv15");
    tv16 = settings.get_strv("tv16");
    tv17 = settings.get_strv("tv17");
    tv18 = settings.get_strv("tv18");
    tv19 = settings.get_strv("tv19");
    tv20 = settings.get_strv("tv20");
  }
  
  private void load_liststore_items()
  {
    liststore.clear();
    add_liststore_iter(tv01);
    add_liststore_iter(tv02);
    add_liststore_iter(tv03);
    add_liststore_iter(tv04);
    add_liststore_iter(tv05);
    add_liststore_iter(tv06);
    add_liststore_iter(tv07);
    add_liststore_iter(tv08);
    add_liststore_iter(tv09);
    add_liststore_iter(tv10);
    add_liststore_iter(tv11);      
    add_liststore_iter(tv12);    
    add_liststore_iter(tv13);    
    add_liststore_iter(tv14);    
    add_liststore_iter(tv15);    
    add_liststore_iter(tv16);      
    add_liststore_iter(tv17);    
    add_liststore_iter(tv18);    
    add_liststore_iter(tv19);    
    add_liststore_iter(tv20); 
    treeview.grab_focus();
  }

  void add_liststore_iter(string[] list)
  {
    Gtk.TreeIter iter;
    if (list[0] != "")
    {
      liststore.append(out iter);
      liststore.set(iter, 0, list[0], 1, list[1], 2, list[2], 3, list[3]);
    }
  }
  
  void play_selected()
  {
    string link; 
    string name;
    Gtk.TreeIter iter;
    Gtk.TreeModel model;
    var selection = treeview.get_selection();
    selection.get_selected(out model, out iter);
    model.get(iter, 3, out link);
    model.get(iter, 2, out name);
    if ( link != "" )
    {
      mpv_stop_playback(FIFO, OUTPUT);
      mpv_video(video_mode, xid, FIFO, link, OUTPUT);
      headerbar.set_title("%s - %s - %s".printf(NAME, name, link));
    }
  }

  // Mouse EventButton Press
  private bool mouse_button_press_events(Gdk.EventButton event)
  {
    if (event.type == Gdk.EventType.2BUTTON_PRESS)
    {
      action_full_screen_toggle();
    }
    return false;
  }

  private void action_reveal_list()
  {
    if (button_list.get_active() == true)
    {
      revealer.set_reveal_child(true);
      treeview.grab_focus();
    }
    else
    {
      revealer.set_reveal_child(false);
      drawing_area.grab_focus();
    }
  }

  // Configure
  private void action_edit_list()
  {
    configure_grid = new Gtk.Grid();
    configure_grid.set_row_spacing(5);
    configure_grid.set_column_spacing(10);
    configure_grid.set_border_width(5);
    
    configure_dialog_add_entry(tv01[0], tv01[1], tv01[2], tv01[3], "tv01", tv01,  1);
    configure_dialog_add_entry(tv02[0], tv02[1], tv02[2], tv02[3], "tv02", tv02,  2);
    configure_dialog_add_entry(tv03[0], tv03[1], tv03[2], tv03[3], "tv03", tv03,  3);
    configure_dialog_add_entry(tv04[0], tv04[1], tv04[2], tv04[3], "tv04", tv04,  4);
    configure_dialog_add_entry(tv05[0], tv05[1], tv05[2], tv05[3], "tv05", tv05,  5);
    configure_dialog_add_entry(tv06[0], tv06[1], tv06[2], tv06[3], "tv06", tv06,  6);
    configure_dialog_add_entry(tv07[0], tv07[1], tv07[2], tv07[3], "tv07", tv07,  7);
    configure_dialog_add_entry(tv08[0], tv08[1], tv08[2], tv08[3], "tv08", tv08,  8);
    configure_dialog_add_entry(tv09[0], tv09[1], tv09[2], tv09[3], "tv09", tv09,  9);
    configure_dialog_add_entry(tv10[0], tv10[1], tv10[2], tv10[3], "tv10", tv10, 10);
    configure_dialog_add_entry(tv11[0], tv11[1], tv11[2], tv11[3], "tv11", tv11, 11);    
    configure_dialog_add_entry(tv12[0], tv12[1], tv12[2], tv12[3], "tv12", tv12, 12);    
    configure_dialog_add_entry(tv13[0], tv13[1], tv13[2], tv13[3], "tv13", tv13, 13);    
    configure_dialog_add_entry(tv14[0], tv14[1], tv14[2], tv14[3], "tv14", tv14, 14);
    configure_dialog_add_entry(tv15[0], tv15[1], tv15[2], tv15[3], "tv15", tv15, 15);
    configure_dialog_add_entry(tv16[0], tv16[1], tv16[2], tv16[3], "tv16", tv16, 16);    
    configure_dialog_add_entry(tv17[0], tv17[1], tv17[2], tv17[3], "tv17", tv17, 17);    
    configure_dialog_add_entry(tv18[0], tv18[1], tv18[2], tv18[3], "tv18", tv18, 18);    
    configure_dialog_add_entry(tv19[0], tv19[1], tv19[2], tv19[3], "tv19", tv19, 19);
    configure_dialog_add_entry(tv20[0], tv20[1], tv20[2], tv20[3], "tv20", tv20, 20);

    var configure_headerbar = new Gtk.HeaderBar();
    configure_headerbar.set_show_close_button(true);
    configure_headerbar.set_title(_("Edit list"));
    
    configure = new Gtk.Dialog();
    configure.set_resizable(false);
    configure.set_icon_name(ICON);
    configure.set_titlebar(configure_headerbar);
    configure.set_transient_for(window);
    
    var scrolled_window = new Gtk.ScrolledWindow(null, null);
    scrolled_window.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.ALWAYS);
    scrolled_window.set_size_request(780, 315);
    scrolled_window.expand = true;
    scrolled_window.add(configure_grid);
    
    var content = configure.get_content_area() as Gtk.Container;
    content.add(scrolled_window);
    
    configure.show_all();
  }

  private void configure_dialog_add_entry(string country, string genre, string name, string url, string save_label, string[] save, int row)
  {

    var entry_country = new Gtk.Entry();
    var entry_genre = new Gtk.Entry();
    var entry_name = new Gtk.Entry();
    var entry_url = new Gtk.Entry();
    
    entry_country.set_text(country);
    entry_genre.set_text(genre);
    entry_name.set_text(name);
    entry_url.set_text(url);    

    entry_country.changed.connect(() => 
    {
      save[0] = entry_country.get_text();
      settings.set_strv(save_label, save); 
    });

    entry_genre.changed.connect(() => 
    {
      save[1] = entry_genre.get_text();
      settings.set_strv(save_label, save); 
    });

    entry_name.changed.connect(() => 
    {
      save[2] = entry_name.get_text();
      settings.set_strv(save_label, save); 
    });

    entry_url.changed.connect(() => 
    {
      save[3] = entry_url.get_text();
      settings.set_strv(save_label, save); 
    });
    
    set_entry_size(entry_country, 50, 0);
    set_entry_size(entry_genre, 50, 0);
    set_entry_size(entry_name, 50, 0);
    set_entry_size(entry_url, 250, 0);
    
    configure_grid.attach(entry_country, 0, row, 1, 1);
    configure_grid.attach(entry_genre,   1, row, 1, 1);
    configure_grid.attach(entry_name,    2, row, 1, 1);
    configure_grid.attach(entry_url,     3, row, 2, 1);
  }

  private void set_entry_size(Gtk.Entry entry_name, int width, int height)
  {
    entry_name.width_request = width;
    entry_name.height_request = height;
  }

  private void action_full_screen_toggle()
  {
    if ((window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) != 0)
    {
      window.unfullscreen();
      Gdk.Window w = window.get_window();
      w.set_cursor(null);
      scrolled.show();
    }
    else
    {
      window.fullscreen();
      var invisible_cursor = new Gdk.Cursor(Gdk.CursorType.BLANK_CURSOR);
      Gdk.Window w = window.get_window();
      w.set_cursor(invisible_cursor);
      scrolled.hide();
    }
  }

  private void action_full_screen_exit()
  {
    window.unfullscreen();
    Gdk.Window w = window.get_window();
    w.set_cursor(null);
    scrolled.show();
  }

  private void action_pause()
  {
    mpv_send_command(FIFO, "cycle pause");
  }

  private void action_show_menu()
  {
    if ((window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) == 0)
    {
      menubutton.set_active(true);
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
    mpv_stop_playback(FIFO, OUTPUT);
    quit();
  }

  private static int main (string[] args)
  {
    Program app = new Program();
    return app.run(args);
  }
}
