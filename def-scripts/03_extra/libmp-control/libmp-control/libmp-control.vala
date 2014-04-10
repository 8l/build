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

namespace LibmpControl
{
  private IOChannel chan;
  private size_t bw;
  
  /* start mpv audio */
  public void mpv_audio(string fifo, string name, string output)
  {
    try
    {
      Process.spawn_command_line_sync("mkfifo '%s'".printf(fifo));
      Process.spawn_command_line_async("sh -c 'mpv -quiet -input file=%s \"%s\" > %s'".printf(fifo, name, output));
      try
      {
        chan= new IOChannel.file("%s".printf(fifo), "r+");
      }
      catch (FileError e)
      {
        stderr.printf ("%s\n", e.message);
      }
    }
    catch (GLib.Error e)
    {
      stderr.printf ("%s\n", e.message);
    }
  }

  /* start mpv audio with volume level */
  public void mpv_audio_with_volume_level(string volume, string fifo, string name, string output)
  {
    try
    {
      Process.spawn_command_line_sync("mkfifo '%s'".printf(fifo));
      Process.spawn_command_line_async("sh -c 'mpv -volume %s -quiet -input file=%s \"%s\" > %s'".printf(volume, fifo, name, output));
      try
      {
        chan= new IOChannel.file("%s".printf(fifo), "r+");
      }
      catch (FileError e)
      {
        stderr.printf ("%s\n", e.message);
      }
    }
    catch (GLib.Error e)
    {
      stderr.printf ("%s\n", e.message);
    }
  }
  
  /* start mpv video with subtitles */
  public void mpv_video_with_subtitles(string video, string subtitle_color, double subtitle_scale, string subtitle_fuzziness, ulong xwindow_id, string fifo, string name, string output)
  {
    try
    {
      Process.spawn_command_line_sync("mkfifo '%s'".printf(fifo));
      Process.spawn_command_line_async("sh -c 'mpv -vo %s -ass --sub-text-color \"%s\" --sub-scale %lf --autosub-match %s -wid %lu --no-mouse-movements -quiet -input file=%s \"%s\" > %s'".printf(video, subtitle_color, subtitle_scale, subtitle_fuzziness, xwindow_id, fifo, name, output));
      try
      {
        chan= new IOChannel.file("%s".printf(fifo), "r+");
      }
      catch (FileError e)
      {
        stderr.printf ("%s\n", e.message);
      }
    }
    catch (GLib.Error e)
    {
      stderr.printf ("%s\n", e.message);
    }
  }  
  
  /* start mpv video */
  public void mpv_video(string video, ulong xwindow_id, string fifo, string name, string output)
  {
    try
    {
      Process.spawn_command_line_sync("mkfifo '%s'".printf(fifo));
      Process.spawn_command_line_async("sh -c 'mpv -vo %s -wid %lu --no-mouse-movements -quiet -input file=%s \"%s\" > %s'".printf(video, xwindow_id, fifo, name, output));
      try
      {
        chan= new IOChannel.file("%s".printf(fifo), "r+");
      }
      catch (FileError e)
      {
        stderr.printf ("%s\n", e.message);
      }
    }
    catch (GLib.Error e)
    {
      stderr.printf ("%s\n", e.message);
    }
  }
  
  /* send command to mpv (one string) */
  public void mpv_send_command(string fifo, string command)
  {
    var fifo_file = File.new_for_path("%s".printf(fifo));
    if (fifo_file.query_exists() == true)
    {
      try
      {
        chan.write_chars("%s\n".printf(command).to_utf8(), out bw);
        chan.flush();
      }
      catch (GLib.Error e)
      {
        stderr.printf ("%s\n", e.message);
      }
    }
  }
  
  /* exit mpv and remove fifo and output files */
  public void mpv_stop_playback(string fifo, string output)
  {
    var fifo_file = File.new_for_path("%s".printf(fifo));
    if (fifo_file.query_exists() == true)
    {
      try
      {
        chan.write_chars("stop\n".to_utf8(), out bw);
        chan.flush();
        Process.spawn_command_line_sync("rm -f %s".printf(fifo));
        Process.spawn_command_line_sync("rm -f %s".printf(output));
      }
      catch (GLib.Error e)
      {
        stderr.printf ("%s\n", e.message);
      }
    }
  }
  
}
