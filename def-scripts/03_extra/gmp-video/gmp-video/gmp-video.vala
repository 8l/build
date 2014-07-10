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
  const string NAME        = "GMP Video";
  const string VERSION     = "1.4.0";
  const string DESCRIPTION = _("Mpv frontend in Vala and GTK3");
  const string ICON        = "gmp-video";
  const string[] AUTHORS   = { "Simargl <archpup-at-gmail-dot-com>", null };
  
  long xid;
  GLib.Settings settings;
  Gtk.Button button_restart;
  Gtk.Button button_pause;
  Gtk.Button button_rewind;
  Gtk.Button button_forward;
  Gtk.Button button_stop;
  Gtk.MenuButton menubutton_document;
  Gtk.MenuButton menubutton_system;
  Gtk.HeaderBar headerbar;
  Gtk.VolumeButton button_volume;
  Gtk.DrawingArea drawing_area;
  Gtk.Grid buttons_grid;
  Gtk.ApplicationWindow window;
  private const Gtk.TargetEntry[] targets = { {"text/uri-list", 0, 0} };
  
  string FIFO;
  string OUTPUT;
  string file;
  string subtitle_file;
  int drawing_area_width;
  int drawing_area_height;
  string video_mode;
  string subtitle_color;
  double subtitle_scale;
  string subtitle_fuzziness;
  bool playing;

  private const GLib.ActionEntry[] action_entries =
  {
    { "pause",              action_pause              },
    { "stop",               action_stop               },
    { "seek-minus-low",     action_seek_minus_low     },
    { "seek-plus-low",      action_seek_plus_low      },
    { "seek-minus-medium",  action_seek_minus_medium  },
    { "seek-plus-medium",   action_seek_plus_medium   },
    { "seek-minus-high",    action_seek_minus_high    },  
    { "seek-plus-high",     action_seek_plus_high     }, 
    { "speed-auto",         action_speed_auto         },
    { "speed-018",          action_speed_018          },
    { "speed-050",          action_speed_050          },
    { "speed-080",          action_speed_080          },
    { "speed-090",          action_speed_090          },
    { "speed-110",          action_speed_110          },
    { "speed-120",          action_speed_120          },
    { "speed-200",          action_speed_200          },
    { "speed-400",          action_speed_400          },
    { "full-screen-exit",   action_full_screen_exit   },
    { "full-screen-toggle", action_full_screen_toggle },
    { "aspect-auto",        action_aspect_auto        },
    { "aspect-11",          action_aspect_11          },
    { "aspect-43",          action_aspect_43          },
    { "aspect-169",         action_aspect_169         },    
    { "aspect-1610",        action_aspect_1610        },
    { "aspect-2211",        action_aspect_2211        },
    { "aspect-2351",        action_aspect_2351        },
    { "aspect-2391",        action_aspect_2391        },
    { "aspect-54",          action_aspect_54          },
    { "zoom-auto",          action_zoom_auto          },
    { "zoom-025",           action_zoom_025           },
    { "zoom-050",           action_zoom_050           },
    { "zoom-double",        action_zoom_double        },
    { "screenshot",         action_screenshot         },
    { "mute",               action_mute               },
    { "volume-minus",       action_volume_minus       },
    { "volume-plus",        action_volume_plus        },
    { "open-file",          action_open_file          },
    { "open-url",           action_open_url_dialog    },
    { "subtitle-select",    action_subtitle_select    },
    { "subtitle-minus",     action_subtitle_minus     },
    { "subtitle-plus",      action_subtitle_plus      },
    { "show-menu",          action_show_menu          },
    { "about",              action_about              },
    { "quit",               action_quit               }
  };

  private Program()
  {
    Object(application_id: "org.alphaos.gmp-video", flags: ApplicationFlags.HANDLES_OPEN);
    add_action_entries(action_entries, this);
  }

  public override void startup()
  {
    base.startup();

    var menu = new GLib.Menu();
    menu.append(_("About"), "app.about");
    menu.append(_("Quit"),  "app.quit");
    
    set_app_menu(menu);

    add_accelerator("space", "app.pause", null);
    add_accelerator("<Control>space", "app.stop", null);
    add_accelerator("Left", "app.seek-minus-low", null);
    add_accelerator("Right", "app.seek-plus-low", null);
    add_accelerator("Down", "app.seek-minus-medium", null); 
    add_accelerator("Up", "app.seek-plus-medium", null);
    add_accelerator("Page_Down", "app.seek-minus-high", null);    
    add_accelerator("Page_Up", "app.seek-plus-high", null);
    add_accelerator("Escape", "app.full-screen-exit", null);
    add_accelerator("F11", "app.full-screen-toggle", null);
    add_accelerator("S", "app.screenshot", null);
    add_accelerator("M", "app.mute", null);
    add_accelerator("9", "app.volume-minus", null);
    add_accelerator("0", "app.volume-plus", null);
    add_accelerator("<Control>O", "app.open-file", null);
    add_accelerator("<Control>U", "app.open-url", null);
    add_accelerator("<Control>S", "app.subtitle-select", null);
    add_accelerator("<Alt>Page_Down", "app.subtitle-minus", null);
    add_accelerator("<Alt>Page_Up", "app.subtitle-plus", null);
    add_accelerator("F10", "app.show-menu", null);
    add_accelerator("<Control>Q", "app.quit", null);
    
    settings = new GLib.Settings("org.alphaos.gmp-video.preferences");
    drawing_area_width = settings.get_int("drawing-area-width");
    drawing_area_height = settings.get_int("drawing-area-height");
    video_mode = settings.get_string("video-mode");
    subtitle_color = settings.get_string("subtitle-color");
    subtitle_scale = settings.get_double("subtitle-scale");
    subtitle_fuzziness = settings.get_string("subtitle-fuzziness");
    
    var submenu_jump_to = new GLib.Menu();
    submenu_jump_to.append(_("-10 seconds"), "app.seek-minus-low");    
    submenu_jump_to.append(_("+10 seconds"), "app.seek-plus-low"); 
    submenu_jump_to.append(_("-30 seconds"), "app.seek-minus-medium"); 
    submenu_jump_to.append(_("+30 seconds"), "app.seek-plus-medium"); 
    submenu_jump_to.append(_("-600 seconds"), "app.seek-minus-high"); 
    submenu_jump_to.append(_("+600 seconds"), "app.seek-plus-high");     

    var submenu_speed = new GLib.Menu();
    submenu_speed.append(_("Auto"), "app.speed-auto");
    submenu_speed.append("0.18", "app.speed-018");
    submenu_speed.append("0.50", "app.speed-050");
    submenu_speed.append("0.80", "app.speed-080");
    submenu_speed.append("0.90", "app.speed-090");
    submenu_speed.append("1.10", "app.speed-110");
    submenu_speed.append("1.20", "app.speed-120");
    submenu_speed.append("2.00", "app.speed-200");
    submenu_speed.append("4.00", "app.speed-400");

    var submenu_aspect = new GLib.Menu();
    submenu_aspect.append(_("Auto"), "app.aspect-auto");
    submenu_aspect.append("1:1", "app.aspect-11");
    submenu_aspect.append("4:3", "app.aspect-43");
    submenu_aspect.append("16:9", "app.aspect-169");
    submenu_aspect.append("16:10", "app.aspect-1610"); 
    submenu_aspect.append("2.21:1", "app.aspect-2211");    
    submenu_aspect.append("2.35:1", "app.aspect-2351");    
    submenu_aspect.append("2.39:1", "app.aspect-2391");
    submenu_aspect.append("5:4", "app.aspect-54");
    
    var submenu_zoom = new GLib.Menu();
    submenu_zoom.append(_("Auto"), "app.zoom-auto");
    submenu_zoom.append(_("Smaller 25%"), "app.zoom-025");
    submenu_zoom.append(_("Smaller 50%"), "app.zoom-050");
    submenu_zoom.append(_("Double size"), "app.zoom-double");

    var section_one = new GLib.Menu();
    section_one.append(_("Pause"), "app.pause");
    section_one.append(_("Stop"), "app.stop");    
    section_one.append_submenu(_("Jump To"), submenu_jump_to);
    section_one.append_submenu(_("Speed"), submenu_speed);
    
    var section_two = new GLib.Menu();
    section_two.append(_("Fullscreen"), "app.full-screen-toggle");
    section_two.append_submenu(_("Aspect Ratio"), submenu_aspect);
    section_two.append_submenu(_("Zoom"), submenu_zoom);
    section_two.append(_("Screenshot"), "app.screenshot");
    
    var section_three = new GLib.Menu();
    section_three.append(_("Mute"), "app.mute");
    section_three.append(_("Volume -"), "app.volume-minus");
    section_three.append(_("Volume +"), "app.volume-plus");    
    
    var section_four = new GLib.Menu();
    section_four.append(_("Open"), "app.open-file");
    section_four.append(_("Open From URL"), "app.open-url");
        
    var section_five = new GLib.Menu();
    section_five.append(_("Select Subtitle"), "app.subtitle-select");
    section_five.append(_("Decrease Font Size"), "app.subtitle-minus");
    section_five.append(_("Increase Font Size"), "app.subtitle-plus");
    
    var gear_menu_document = new GLib.Menu();
    var gear_menu_system = new GLib.Menu();    
    gear_menu_document.append_section(null, section_one);
    gear_menu_document.append_section(null, section_two);
    gear_menu_document.append_section(null, section_three);
    gear_menu_system.append_section(null, section_four);
    gear_menu_system.append_section(null, section_five);

    string random_number = GLib.Random.int_range(1000, 5000).to_string();
    FIFO = "/tmp/gmp_video_fifo_" + random_number;
    OUTPUT = "/tmp/gmp_video_output_" + random_number;
    
    drawing_area = new Gtk.DrawingArea();
    drawing_area.set_size_request(drawing_area_width, drawing_area_height);
    drawing_area.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
    drawing_area.add_events(Gdk.EventMask.SCROLL_MASK);
    drawing_area.button_press_event.connect(mouse_button_press_events);
    drawing_area.scroll_event.connect(mouse_button_scroll_events);
    drawing_area.set_vexpand(true);
    drawing_area.set_hexpand(true);
    
    button_restart = new Gtk.Button.from_icon_name("view-refresh-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    button_pause = new Gtk.Button();
    button_pause_set_image();
    button_rewind = new Gtk.Button.from_icon_name("media-skip-backward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    button_forward = new Gtk.Button.from_icon_name("media-skip-forward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    button_stop = new Gtk.Button.from_icon_name("media-playback-stop-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    button_volume = new Gtk.VolumeButton();
    button_volume.use_symbolic = true;
    button_volume.set_value(1.00);

    button_restart.clicked.connect(() => { gmp_video_start_playback(); });
    button_pause.clicked.connect(action_pause);
    button_rewind.clicked.connect(action_seek_minus_medium);
    button_forward.clicked.connect(action_seek_plus_medium);
    button_stop.clicked.connect(() => { mpv_stop_playback(FIFO, OUTPUT); headerbar.set_title(NAME); playing = false; button_pause_set_image(); });
    button_volume.value_changed.connect(volume_level_changed);

    set_button_size_relief_focus(button_restart);
    set_button_size_relief_focus(button_pause);
    set_button_size_relief_focus(button_rewind);
    set_button_size_relief_focus(button_forward);
    set_button_size_relief_focus(button_stop);
    set_button_size_relief_focus(button_volume);

    var label1 = new Gtk.Label("");
    var label2 = new Gtk.Label("");
    
    buttons_grid = new Gtk.Grid();
    buttons_grid.attach(button_restart, 0, 0, 1, 1);
    buttons_grid.attach(label1,         1, 0, 2, 1);
    buttons_grid.attach(button_pause,   3, 0, 1, 1);
    buttons_grid.attach(button_rewind,  4, 0, 1, 1);
    buttons_grid.attach(button_forward, 5, 0, 1, 1);
    buttons_grid.attach(button_stop,    6, 0, 1, 1);
    buttons_grid.attach(label2,         7, 0, 2, 1);
    buttons_grid.attach(button_volume,  9, 0, 1, 1);
    
    buttons_grid.set_column_spacing(5);
    buttons_grid.set_border_width(5);
    buttons_grid.set_row_homogeneous(true);
    buttons_grid.set_column_homogeneous(true);
    
    var grid = new Gtk.Grid();
    grid.attach(drawing_area, 0, 0, 1, 1);
    grid.attach(buttons_grid,  0, 1, 1, 1);

    menubutton_document = new Gtk.MenuButton();
    menubutton_document.valign = Gtk.Align.CENTER;
    menubutton_document.set_menu_model(gear_menu_document);
    menubutton_document.set_image(new Gtk.Image.from_icon_name("document-properties-symbolic", Gtk.IconSize.MENU));

    menubutton_system = new Gtk.MenuButton();
    menubutton_system.valign = Gtk.Align.CENTER;
    menubutton_system.set_menu_model(gear_menu_system);
    menubutton_system.set_image(new Gtk.Image.from_icon_name("emblem-system-symbolic", Gtk.IconSize.MENU));

    headerbar = new Gtk.HeaderBar();
    headerbar.set_show_close_button(true);
    headerbar.pack_end(menubutton_system);
    headerbar.pack_end(menubutton_document);
    headerbar.set_title(NAME);
    
    window = new Gtk.ApplicationWindow(this);
    window.set_titlebar(headerbar);
    window.add(grid);
    window.set_icon_name(ICON);
    window.show_all();
    window.delete_event.connect(() => { action_quit(); return true; });

    Gtk.drag_dest_set(grid, Gtk.DestDefaults.ALL, targets, Gdk.DragAction.COPY);
    grid.drag_data_received.connect(on_drag_data_received);
    
    var drawing_area_window = (Gdk.X11.Window)drawing_area.get_window();
    xid = (long)drawing_area_window.get_xid();
  }

  public override void activate() 
  {
    window.present();
  }
  
  public override void open(File[] files, string hint)
  {
    window.present();
    foreach (File f in files)
    {
      file = f.get_path();
    }
    gmp_video_start_playback();
  }  

  private void set_button_size_relief_focus(Gtk.Button button_name)
  {
    button_name.set_relief(Gtk.ReliefStyle.NONE);
    button_name.set_can_focus(false);
  }
  
  private void button_pause_set_image()
  {
    Gtk.Image image_play_pause;
    if (playing == true)
    {
      image_play_pause = new Gtk.Image.from_icon_name("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    }
    else
    {
      image_play_pause = new Gtk.Image.from_icon_name("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    }
    button_pause.set_image(image_play_pause);
    button_pause.set_always_show_image(true);
  }
  
  private void volume_level_changed()
  {
    double level = button_volume.get_value() * 100;
    mpv_send_command(FIFO, "no-osd set volume %s".printf(level.to_string()));
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
  
  // Mouse EventButton Scroll
  private bool mouse_button_scroll_events(Gdk.EventScroll event)
  {
    if (event.direction == Gdk.ScrollDirection.UP)
    {
      action_seek_plus_medium();
    }
    if (event.direction == Gdk.ScrollDirection.DOWN)
    {
      action_seek_minus_medium();
    }
    return false;
  }

  // Drag Data
  private void on_drag_data_received(Gdk.DragContext drag_context, int x, int y, Gtk.SelectionData data, uint info, uint time) 
  {
    foreach(string uri in data.get_uris())
    {
      file = uri.replace("file://", "");
      file = Uri.unescape_string(file);
      gmp_video_start_playback();
    }
    Gtk.drag_finish(drag_context, true, false, time);
  }

  private void gmp_video_start_playback()
  {
    var basename = Path.get_basename(file);
    mpv_stop_playback(FIFO, OUTPUT);
    mpv_video_with_subtitles(video_mode, subtitle_color, subtitle_scale, subtitle_fuzziness, xid, FIFO, file, OUTPUT);
    button_volume.set_value(1.00);
    headerbar.set_title("%s - %s".printf(NAME, basename));
    playing = true;
    button_pause_set_image();
    mpv_send_command(FIFO, "show_progress");
  }

  private void action_pause()
  {
    mpv_send_command(FIFO, "cycle pause");
    if (playing == true)
    {
      playing = false;
    }
    else
    {
      playing = true;
    }
    button_pause_set_image();
  }
  
  private void action_stop()
  {
    mpv_stop_playback(FIFO, OUTPUT);
  }

  private void action_seek_minus_low()
  {
    mpv_send_command(FIFO, "seek -10");
  }

  private void action_seek_plus_low()
  {
    mpv_send_command(FIFO, "seek +10");
  }

  private void action_seek_minus_medium()
  {
    mpv_send_command(FIFO, "seek -30");
  }

  private void action_seek_plus_medium()
  {
    mpv_send_command(FIFO, "seek +30");
  }
  
  private void action_seek_minus_high()
  {
    mpv_send_command(FIFO, "seek -600");
  }  
  
  private void action_seek_plus_high()
  {
    mpv_send_command(FIFO, "seek +600");
  }

  private void action_speed_auto()
  {
    mpv_send_command(FIFO, "set speed 1.00");
  }

  private void action_speed_018()
  {
    mpv_send_command(FIFO, "set speed 0.18");
  }
   
  private void action_speed_050()
  {
    mpv_send_command(FIFO, "set speed 0.50");
  }
  
  private void action_speed_080()
  {
    mpv_send_command(FIFO, "set speed 0.80");
  }
  
  private void action_speed_090()
  {
    mpv_send_command(FIFO, "set speed 0.90");
  }
   
  private void action_speed_110()
  {
    mpv_send_command(FIFO, "set speed 1.10");
  }
  
  private void action_speed_120()
  {
    mpv_send_command(FIFO, "set speed 1.20");
  }
  
  private void action_speed_200()
  {
    mpv_send_command(FIFO, "set speed 3.00");
  }
  
  private void action_speed_400()
  {
    mpv_send_command(FIFO, "set speed 4.00");
  }

  private void action_full_screen_exit()
  {
    window.unfullscreen();
    Gdk.Window w = window.get_window();
    w.set_cursor(null);
    buttons_grid.show();
  }
  
  private void action_full_screen_toggle()
  {
    if ((window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) != 0)
    {
      action_full_screen_exit();
    }
    else
    {
      window.fullscreen();
      var invisible_cursor = new Gdk.Cursor(Gdk.CursorType.BLANK_CURSOR);
      Gdk.Window w = window.get_window();
      w.set_cursor(invisible_cursor);
      buttons_grid.hide();
    }
  }

  private void action_aspect_auto()
  {
    mpv_send_command(FIFO, "set video-aspect 0.000000000");
  }

  private void action_aspect_11()
  {
    mpv_send_command(FIFO, "set video-aspect 1.000000000");
  }
  
  private void action_aspect_43()
  {
    mpv_send_command(FIFO, "set video-aspect 1.333333339");
  }
  
  private void action_aspect_169()
  {
    mpv_send_command(FIFO, "set video-aspect 1.777777778");
  }    
  
  private void action_aspect_1610()
  {
    mpv_send_command(FIFO, "set video-aspect 1.600000000");
  }
  
  private void action_aspect_2211()
  {
    mpv_send_command(FIFO, "set video-aspect 2.210000000");
  }  
  
  private void action_aspect_2351()
  {
    mpv_send_command(FIFO, "set video-aspect 2.350000000");
  }  
  
  private void action_aspect_2391()
  {
    mpv_send_command(FIFO, "set video-aspect 2.390000000");
  }  
  
  private void action_aspect_54()
  {
    mpv_send_command(FIFO, "set video-aspect 1.250000000");
  }
  
  private void action_zoom_auto()
  {
    mpv_send_command(FIFO, "set video-zoom 0");
  }

  private void action_zoom_025()
  {
    mpv_send_command(FIFO, "set video-zoom -0.25");
  }

  private void action_zoom_050()
  {
    mpv_send_command(FIFO, "set video-zoom -0.50");
  }
    
  private void action_zoom_double()
  {
    mpv_send_command(FIFO, "set video-zoom 1.00");
  }
  
  private void action_screenshot()
  {
    GLib.DateTime gdate = new GLib.DateTime.now_local();
    string date = gdate.get_year().to_string() + gdate.get_month().to_string() + gdate.get_day_of_month().to_string() + gdate.get_hour().to_string() + gdate.get_minute().to_string() + gdate.get_second().to_string();
    mpv_send_command(FIFO, "screenshot_to_file \"%s\" video".printf(GLib.Environment.get_home_dir()+ "/" + "shot-" + date + ".jpg"));
  }

  private void action_mute()
  {
    mpv_send_command(FIFO, "mute");
  }

  private void action_volume_minus()
  {
    button_volume.set_value(button_volume.get_value() - 0.1);
  }
  
  private void action_volume_plus()
  {
    button_volume.set_value(button_volume.get_value() + 0.1);
  }

  private void action_open_file()
  {
   var dialog = new Gtk.FileChooserDialog(_("Open"), window, Gtk.FileChooserAction.OPEN,
                                        "gtk-cancel", Gtk.ResponseType.CANCEL,
                                        "gtk-open", Gtk.ResponseType.ACCEPT);
   var filter = new Gtk.FileFilter();
   filter.set_filter_name(_("All Media Files"));
   filter.add_mime_type("audio/*");
   filter.add_mime_type("video/*");
   filter.add_mime_type("application/x-matroska");
   filter.add_mime_type("image/gif");
   dialog.add_filter(filter);
   dialog.set_transient_for(window);
   dialog.set_select_multiple(false);
   if (file != null)
   {
     dialog.set_current_folder(Path.get_dirname(file));
   }
   if (dialog.run() == Gtk.ResponseType.ACCEPT)
   {
     file = dialog.get_filename();
     gmp_video_start_playback();
   }
   dialog.destroy();
  }
  
  private void action_open_url_dialog()
  {
    var play_url_dialog = new Gtk.Dialog();
    play_url_dialog.set_title(_("Open From URL"));
    play_url_dialog.set_border_width(10);
    play_url_dialog.set_property("skip-taskbar-hint", true);
    play_url_dialog.set_transient_for(window);
    play_url_dialog.set_resizable(false);

    var play_url_entry = new Gtk.Entry();
    play_url_entry.set_size_request(450, 0);
    play_url_entry.activate.connect(() => { action_open_url_dialog_on_response(play_url_entry, play_url_dialog); });

    var content = play_url_dialog.get_content_area() as Gtk.Box;
    content.pack_start(play_url_entry, true, true, 10);

    play_url_dialog.add_button(_("Play"), Gtk.ResponseType.OK);
    play_url_dialog.add_button(_("Close"), Gtk.ResponseType.CLOSE);
    play_url_dialog.set_default_response(Gtk.ResponseType.OK);
    play_url_dialog.show_all();
    if (play_url_dialog.run() == Gtk.ResponseType.OK)
    {
      action_open_url_dialog_on_response(play_url_entry, play_url_dialog);
    }
    play_url_dialog.destroy();
  }

  private void action_open_url_dialog_on_response(Gtk.Entry entry, Gtk.Dialog dialog)
  {
    file = entry.get_text();
    if (file != "")
    {
      gmp_video_start_playback();
    }
    dialog.destroy();
  }  

  private void action_subtitle_select()
  {
    var dialog = new Gtk.FileChooserDialog(_("Select Subtitle"), window, Gtk.FileChooserAction.OPEN,
                                         "gtk-cancel", Gtk.ResponseType.CANCEL,
                                         "gtk-open", Gtk.ResponseType.ACCEPT);
    var filter = new Gtk.FileFilter();
    filter.set_filter_name("Subtitle Files");
    filter.add_mime_type("application/x-subrip");
    filter.add_mime_type("text/x-microdvd");
    dialog.add_filter(filter);
    dialog.set_transient_for(window);
    dialog.set_select_multiple(false);
    if (file != null)
    {
      dialog.set_current_folder(Path.get_dirname(file));
    }
    if (dialog.run() == Gtk.ResponseType.ACCEPT)
    {
      subtitle_file = dialog.get_filename();
      mpv_send_command(FIFO, "sub_add \"%s\"".printf(subtitle_file));
      mpv_send_command(FIFO, "cycle sub 0");
    }
    dialog.destroy();
  }
  
  private void action_subtitle_minus()
  {
    mpv_send_command(FIFO, "add sub-scale -0.5");
  }  
  
  private void action_subtitle_plus()
  {
    mpv_send_command(FIFO, "add sub-scale +0.5");
  }

  private void action_show_menu()
  {
    if ((window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) == 0)
    {
      menubutton_system.set_active(true);
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
    action_stop();
    quit();
  }

  private static int main (string[] args)
  {
    Program app = new Program();
    return app.run(args);
  }
}
