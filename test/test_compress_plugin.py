#!/usr/bin/env python3

import os
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    'yt-dlp-plugins', 'compress'))

from yt_dlp_plugins.postprocessor.compress import (  # noqa: E402
    choose_height,
    parse_target_bytes,
    plan_encode,
    quality_floors,
)


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class TestCompressPlan(unittest.TestCase):
    def test_target_units(self):
        self.assertEqual(parse_target_bytes('1GB'), 1_000_000_000)
        self.assertEqual(parse_target_bytes('1GiB'), 1024 ** 3)
        self.assertEqual(parse_target_bytes('500MB'), 500_000_000)

    def test_full_hd_frame_stays_1920x1080_on_a_long_movie(self):
        plan = plan_encode(
            target_bytes=1_000_000_000,
            duration=3 * 3600,
            source_height=2160,
            audio_bps=128_000,
            audio_count=1,
            encoder='libx265',
            preset='medium',
            frame_size=(1920, 1080),
        )
        self.assertEqual((plan.width, plan.height), (1920, 1080))
        self.assertTrue(any('1920x1080' in note for note in plan.notes))

    def test_two_hour_4k_movie_uses_720p(self):
        plan = plan_encode(
            target_bytes=1_000_000_000,
            duration=2 * 3600,
            source_height=2160,
            audio_bps=128_000,
            audio_count=1,
            encoder='libx265',
            preset='medium',
        )
        self.assertEqual(plan.height, 720)
        self.assertEqual(plan.passes, 2)
        self.assertGreater(plan.video_bps, 800_000)
        self.assertLess(plan.video_bps, 1_100_000)
        self.assertTrue(any('720p' in note for note in plan.notes))

    def test_one_hour_film_stays_1080p(self):
        plan = plan_encode(
            target_bytes=1_000_000_000,
            duration=3600,
            source_height=2160,
            audio_bps=128_000,
            audio_count=1,
            encoder='libx265',
            preset='medium',
        )
        self.assertEqual(plan.height, 1080)

    def test_short_clip_keeps_4k(self):
        plan = plan_encode(
            target_bytes=1_000_000_000,
            duration=600,
            source_height=2160,
            audio_bps=128_000,
            audio_count=1,
            encoder='libx265',
            preset='medium',
        )
        self.assertIsNone(plan.height)

    def test_maxheight_without_autoscale_caps(self):
        plan = plan_encode(
            target_bytes=1_000_000_000,
            duration=600,
            source_height=2160,
            audio_bps=128_000,
            audio_count=1,
            encoder='libx265',
            preset='medium',
            max_height=1080,
            autoscale=False,
        )
        self.assertEqual(plan.height, 1080)

    def test_h264_needs_a_smaller_frame_than_hevc(self):
        # 90 minutes at 1GB is enough for 1080p HEVC and only 720p H.264.
        common = dict(
            target_bytes=1_000_000_000,
            duration=90 * 60,
            source_height=1080,
            audio_bps=128_000,
            audio_count=1,
            preset='medium',
        )
        hevc = plan_encode(encoder='libx265', **common)
        h264 = plan_encode(encoder='libx264', **common)
        self.assertIsNone(hevc.height)
        self.assertEqual(h264.height, 720)

    def test_hardware_encoder_is_one_pass(self):
        plan = plan_encode(
            target_bytes=1_000_000_000,
            duration=3600,
            source_height=1080,
            audio_bps=128_000,
            audio_count=1,
            encoder='hevc_videotoolbox',
            preset='medium',
        )
        self.assertEqual(plan.passes, 1)

    def test_crf_mode_does_not_shrink_resolution(self):
        plan = plan_encode(
            target_bytes=1_000_000_000,
            duration=2 * 3600,
            source_height=1080,
            audio_bps=128_000,
            audio_count=1,
            encoder='libx265',
            preset='medium',
            crf=28,
        )
        self.assertIsNone(plan.height)
        self.assertEqual(plan.crf, 28)
        self.assertEqual(plan.passes, 1)
        self.assertIsNone(plan.video_bps)

    def test_many_audio_tracks_give_room_back_to_video(self):
        plan = plan_encode(
            target_bytes=1_000_000_000,
            duration=2 * 3600,
            source_height=1080,
            audio_bps=128_000,
            audio_count=8,
            encoder='libx265',
            preset='medium',
        )
        self.assertLess(plan.audio_bps, 128_000)
        self.assertTrue(plan.notes)

    def test_choose_height_keeps_source_when_it_already_fits(self):
        height, under = choose_height(720, 2_000_000, None, True, quality_floors('libx265'))
        self.assertIsNone(height)
        self.assertFalse(under)

    def test_plugin_loads_in_yt_dlp(self):
        script = f'''
import yt_dlp.postprocessor
from yt_dlp.globals import plugin_dirs
from yt_dlp.plugins import load_all_plugins
from yt_dlp.postprocessor import get_postprocessor
plugin_dirs.value = [{os.path.join(ROOT, "yt-dlp-plugins")!r}]
load_all_plugins()
cls = get_postprocessor("Compress")
assert cls.__name__ == "CompressPP", cls
'''
        completed = subprocess.run(
            [sys.executable, '-c', script], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)


def _ffmpeg_available():
    return shutil.which('ffmpeg') and shutil.which('ffprobe')


@unittest.skipUnless(_ffmpeg_available(), 'ffmpeg and ffprobe are required')
class TestCompressEncode(unittest.TestCase):
    def _source(self, directory):
        path = os.path.join(directory, 'source.mp4')
        subprocess.run([
            'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error',
            '-f', 'lavfi', '-i', 'testsrc=size=160x120:rate=12:duration=1',
            '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=44100:duration=1',
            '-c:v', 'libx264', '-preset', 'ultrafast', '-b:v', '1500k',
            '-c:a', 'aac', '-shortest', path,
        ], check=True)
        return path

    def _run(self, path, **kwargs):
        from yt_dlp_plugins.postprocessor.compress import CompressPP

        class _Log:
            params = {}
            messages = []

            def to_screen(self, text, *args, **kw):
                self.messages.append(text)

            def report_warning(self, text, *args, **kw):
                self.messages.append(text)

            def write_debug(self, text, *args, **kw):
                pass

            def evaluate_outtmpl(self, tmpl, info_dict):
                return ''

            def to_console_title(self, message, progress_state=None, percent=None):
                return None

        log = _Log()
        pp = CompressPP(log, **kwargs)
        _files, info = pp.run({'filepath': path, 'ext': 'mp4'})
        return _files, info, log

    def test_dry_run_leaves_the_file(self):
        with tempfile.TemporaryDirectory() as directory:
            source = self._source(directory)
            before = os.path.getsize(source)
            deleted, info, log = self._run(source, target='20KB', codec='h264', preset='ultrafast', dryrun='1')
            self.assertEqual(deleted, [])
            self.assertEqual(info['filepath'], source)
            self.assertEqual(os.path.getsize(source), before)
            self.assertTrue(any('Dry run' in message for message in log.messages))
            self.assertTrue(any('1920x1080' in message for message in log.messages))

    def test_two_pass_h264_shrinks_under_target(self):
        with tempfile.TemporaryDirectory() as directory:
            source = self._source(directory)
            before = os.path.getsize(source)
            deleted, info, log = self._run(
                source, target='40KB', codec='h264', preset='ultrafast', size='source',
                maxheight='120', audio='32k', autoscale='0')
            self.assertEqual(deleted, [])
            self.assertEqual(info['filepath'], source)
            self.assertLess(info['filesize'], before)
            probe = subprocess.run([
                'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                '-of', 'csv=p=0', source,
            ], check=True, capture_output=True, text=True)
            self.assertGreater(float(probe.stdout.strip()), 0.5)
            self.assertTrue(any('libx264' in message for message in log.messages))

    def test_other_container_is_returned_for_deletion(self):
        with tempfile.TemporaryDirectory() as directory:
            source = os.path.join(directory, 'source.mkv')
            subprocess.run([
                'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error',
                '-f', 'lavfi', '-i', 'testsrc=size=160x120:rate=12:duration=1',
                '-f', 'lavfi', '-i', 'sine=frequency=440:duration=1',
                '-c:v', 'libx264', '-preset', 'ultrafast', '-b:v', '1500k', '-c:a', 'aac', '-shortest', source,
            ], check=True)
            deleted, info, _log = self._run(
                source, target='30KB', codec='h264', preset='ultrafast', size='source',
                audio='32k', autoscale='0')
            self.assertEqual(deleted, [source])
            self.assertTrue(info['filepath'].endswith('.mp4'))
            self.assertTrue(os.path.exists(source))
            self.assertTrue(os.path.exists(info['filepath']))

    def test_output_is_1920x1080(self):
        with tempfile.TemporaryDirectory() as directory:
            source = self._source(directory)
            _deleted, info, _log = self._run(
                source, target='1KB', codec='h264', preset='ultrafast', passes='1', audio='32k', force='1')
            probe = subprocess.run([
                'ffprobe', '-v', 'error', '-select_streams', 'v:0',
                '-show_entries', 'stream=width,height', '-of', 'csv=p=0', info['filepath'],
            ], check=True, capture_output=True, text=True)
            self.assertEqual(probe.stdout.strip(), '1920,1080')


if __name__ == '__main__':
    unittest.main()
