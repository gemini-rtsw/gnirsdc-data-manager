#!/usr/bin python3

import argparse
from astropy.io import fits
from astropy.time import Time
from astropy import wcs
import cgi
import datetime
import dateutil.parser
import json
import logging
import numpy
import os
import sys
import time
import urllib.request, urllib.parse, urllib.error
import warnings

# __version__ = '2018-Jul-22'  # Andrew Stephens, initial version
# __version__ = '2018-Jul-28'  # astephens, cleanup
# __version__ = '2018-Aug-21'  # astephens, support querying a single file
# __version__ = '2019-Apr-17'  # astephens
# __version__ = '2019-Nov-15'  # astephens, branched off of fits-query-gnirs-wcs.py
# __version__ = '2019-Nov-27'  # astephens, change missing obstype to INFO to avoid cron emails
# __version__ = '2019-Dec-24'  # astephens, re-query the fits server after HTTP errors
# __version__ = '2019-Dec-28'  # astephens, re-query the fits server header query too
# __version__ = '2020-Feb-01'  # astephens, fix dumb bug
# __version__ = '2020-Feb-04'  # astephens, add a delay between each server retry
# __version__ = '2020-Mar-11'  # astephens, include MJD in output
# __version__ = '2020-Jul-07'  # astephens, output the target name
# __version__ = '2020-Jul-13'  # astephens, catch missing WCS
# __version__ = '2020-Aug-31'  # astephens
# __version__ = '2020-Nov-20'  # astephens, fix bug parsing target names with slashes
# __version__ = '2022-Feb-02'  # astephens, include proper motion and catch ERFA warnings with old versions of astropy
# __version__ = '2022-Feb-03'  # astephens, add web interface
# __version__ = '2022-Feb-03'  # astephens, remove ERFA warning override
# __version__ = '2022-Jul-14'  # astephens, give link to full report
# __version__ = '2023-Jun-21'  # astephens, print local time
# __version__ = '2023-Jul-03'  # astephens, include telescope offsets
# __version__ = '2023-Dec-27'  # astephens, ignore non-sidereally tracked observations
# __version__ = '2024-Feb-06'  # astephens, update URL
__version__ = '2024-Dec-31'  # astephens, catch ERFA warnings with old versions of astropy

# --------------------------------------------------------------------------------------------------

def main(args):

    if args.webapp:
        webapp(args)
    else:
        calculate(args)
    return

# -------------------------------------------------------------------------------------------------

def webapp(args):
    form = cgi.FieldStorage()
    args.date = form.getvalue('date')
    args.all = True  # Show all files
    args.loglevel = 'error'
    print('Content-type: text/html\x0D\x0A')
    print('<html>')
    print('<head>')
    print('<title>GNRS WCS Check</title>')
    print('</head>')
    print('<body>')
    print('<form action="gnirs-check-wcs.py" method="get">')
    today = datetime.datetime.utcnow().strftime('%Y-%m-%d')
    print('<input type="date" id="date" name="date" value="%s">' % today)
    print('&nbsp; <input name="go" value="Go!" type="submit">')
    print('<hr>')
    if args.date is not None:
        print('<pre>')
        calculate(args)
        print('</pre>')
    print('</body>')
    print('</html>')
    return

# -------------------------------------------------------------------------------------------------

def calculate(args):
    logging.basicConfig(format='%(asctime)s %(name)-12s %(levelname)-8s %(message)s',
                        level=getattr(logging, args.loglevel.upper()))
    logger = logging.getLogger('main')

    if args.file is not None:
        checkfile(args.file)
        return

    any_bad = False
    startdate = dateutil.parser.parse(args.date).date()
    enddate = (dateutil.parser.parse(args.enddate).date() if args.enddate else startdate)
    logger.debug('Start date: %s', startdate)
    logger.debug('End date: %s', enddate)
    deltadays = 10  # The limit is 10k files per query, so step by 10 days
    for d in range(0, (enddate-startdate).days + 1, deltadays):
        start = startdate + datetime.timedelta(days=d)
        end = min(startdate + datetime.timedelta(days=d + deltadays - 1), enddate)
        daterange = start.strftime('%Y%m%d') + '-' + end.strftime('%Y%m%d')
        logger.info('Date Range: %s', daterange)

        # jsonsummary does not include all FITS header keywords, so get the filelist and read each:
        url = 'http://fits.hi.gemini.edu/jsonfilelist/GNIRS/NotFail/canonical/' + daterange + '?orderby=filename_desc'
        logger.debug('URL: %s', url)
        u = query(url)
        jsondoc = u.read()
        u.close()
        values = json.loads(jsondoc)
        logger.debug('values = %s', values)
        logger.info('Found %s files', len(values))

        for v in values:
            logger.debug('-----------------------------------')
            bad = checkfile(v['name'])
            if bad:
                any_bad = True

    if any_bad and not args.webapp:
        print(f'\nhttp://hbfsciops-lv1.hi.gemini.edu/cgi-bin/gnirs-check-wcs.py?date={startdate}')

    return

# --------------------------------------------------------------------------------------------------
# Occasionally a fits server query fails with an HTTP error so retry a few times

def query(url, retries=5, wait=5):
    logger = logging.getLogger('query')
    logger.info('Querying %s', url)

    for i in range(retries):

        try:
            u = urllib.request.urlopen(url)
 
        except urllib.error.HTTPError as e:  # this works!
            print('Attempt %d: HTTPError: %s' % (i,e))
            u = None  # retry

        except urllib.error.URLError as e:
            logger.error('URLError: %s', e)
            raise SystemExit

        except:
            logger.error('Error: %s', sys.exc_info()[0])
            raise SystemExit

        if u is not None:
            if i > 0:
                print('Success!')
            return u
        else:
            print('Retrying in %d seconds...' % wait)
            time.sleep(wait)

    else:
        logger.warning('Giving up on %s', url)
        raise SystemExit
      

# --------------------------------------------------------------------------------------------------

def checkfile(fitsfile):
    """
    Compare the FITS header RA and DEC keywords with the WCS.
    string fitsfile: file name to query
    """
    logger = logging.getLogger('checkfile')

    logger.info('')
    logger.info('%s', fitsfile)

    url = 'http://fits.hi.gemini.edu/fullheader/' + fitsfile
    logger.debug('URL: %s', url)
    u = query(url)
    fullheader = u.read()
    u.close()
    logger.debug('%s', fullheader)

    keys = fitsheadparse(fullheader)

    try:
        obstype = keys['OBSTYPE']
        if obstype != 'OBJECT' and not args.force:
            logger.info('Skipping %s', obstype)
            return
    except:
        logger.info('Skipping %s because missing OBSTYPE keyword', fitsfile)
        return

    datalabel = keys['DATALAB']
    logger.info('Datalabel: %s', datalabel)
    logger.info('Instrument: %s', keys['INSTRUME'])
    logger.info('Object: %s', keys['OBJECT'])
    logger.info('Acq Mirror: %s', keys['ACQMIR'])
    target = keys['OBJECT']

    try:
        mjd = keys['MJD_OBS']
    except:
        print('%s WCS is missing, %s, %s' % (fitsfile, datalabel, target))
        return
    mjd_ut = mjd2ut(mjd)
    logger.info('MJD: %s -> %s', mjd, mjd_ut)

    # Build a header to avoid downloading the whole image
    header = fits.Header()              # create a new header object
    for k in keys:                      # and add all the keys
        header.append((k, keys[k]))
    w = wcs.WCS(header)
    # w.wcs.print_contents()

    dateobs = keys['DATE-OBS']
    timeobs = keys['TIME-OBS']
    # ut = pytz.utc.localize(dateutil.parser.parse(dateobs + ' ' + timeobs))
    ut = dateutil.parser.parse(dateobs + ' ' + timeobs)
    logger.info('UT: %s', ut)

    mjd_err = abs(ut - mjd_ut)  # avoid numbers like "-1 day, 22:48:20"
    logger.info('MJD error: %s', mjd_err)

    # This does not work in the older version of astropy installed on the telops account:
    # AttributeError: 'Time' object has no attribute 'to_value'
    # epochobs = Time(ut, format='datetime', scale='utc').to_value('decimalyear')
    # logger.debug('Epoch of observation: %s', epochobs)
    # So make an approximation of the epoch of observation:
    jan1 = dateutil.parser.parse(f'{ut.year} Jan 1')
    dec31 = dateutil.parser.parse(f'{ut.year} Dec 31 at 11:59:59.999999')
    epochobs = ut.year + (ut - jan1) / (dec31 - jan1)
    logger.debug('Epoch of observation: %s', epochobs)

    nonsidereal = True if (keys['FRAME'] == 'APPT') else False
    logger.debug('nonsidereal: %s', nonsidereal)

    ra = keys['RA']
    dec = keys['DEC']
    epoch = keys['EPOCH']  # Epoch of coordinates
    logger.info('RA:  %s deg', ra)
    logger.info('DEC: %s deg', dec)

    ra_offset = keys['RAOFFSET']   # Telescope offset in RA in arcsec
    dec_offset = keys['DECOFFSE']  # Telescope offset in DEC in arcsec
    logger.info('RAOFFSET:  %.2f arcsec', ra_offset)
    logger.info('DECOFFSET: %.2f arcsec', dec_offset)

    pmra = keys['PMRA']    # Target Proper Motion in RA (seconds/year)
    pmdec = keys['PMDEC']  # Target Proper Motion in Dec (arcsec/year)
    dt = epochobs - epoch
    logger.debug('dt: %s yr', dt)
    logger.info('PMRA: %s sec/yr (%.2f arcsec)', pmra, dt * pmra * 15. * numpy.cos(dec / 180.0 * numpy.pi))
    logger.info('PMDEC: %s arcsec/yr (%.2f arcsec)', pmdec, dt * pmdec)

    logger.debug('Converting the central pixel coordinate to RA, Dec...')
    # radec = wcs.utils.pixel_to_skycoord(512, 512, w)
    wcsra, wcsdec = w.wcs_pix2world(512., 512., 1)  # 1 -> pixel coordinates start at (1,1)
    logger.info('WCS RA: %s deg', wcsra)
    logger.info('WCS Dec: %s deg', wcsdec)

    dra = (wcsra - (ra + ra_offset / 3600.0 + pmra * 15.0 / 3600.0 * dt)) * numpy.cos(dec / 180.0 * numpy.pi)
    ddec = wcsdec - (dec + dec_offset / 3600.0 + pmdec / 3600.0 * dt)
    offset = numpy.sqrt(dra**2 + ddec**2) * 3600.0
    logger.info('Offset: %.1f arcsec', offset)

    if args.all or (offset > 60.0 and not nonsidereal):
        lt = keys['LT']
        print(f'{fitsfile} @ {lt}: WCS difference is {offset:.0f} arcsec, {datalabel}, {target}')

    return offset > 60.0 and not nonsidereal  # return True if the WCS is bad

# --------------------------------------------------------------------------------------------------

def fitsheadparse(header):
    """
    Parse a FITS header extension 0 from the Gemini FITS server and return a dictionary of keywords
    and their associated values with the correct types.
    """
    logger = logging.getLogger('fitsheadparse')
    data = {}
    for line in header.decode('utf-8').splitlines():
        if '=' in line:
            key = line[0:line.find('=')].strip("\'").strip()
            val = line[line.find('=')+1:line.rfind('/')].strip().strip("\'")
            try:
                if '.' in val:  # float
                    data[key] = float(val)    
                else:           # integer
                    data[key] = int(val)
            except:             # string
                data[key] = val.strip()
        elif 'HDU 1' in line:
            break
        
    # Now set the NAXIS keywords from HDU 1:
    for line in header.decode('utf-8').splitlines():
        if '=' in line and 'NAXIS' in line:
            key = line[0:line.find('=')].strip("\'").strip()
            val = line[line.find('=')+1:line.find('/')].strip().strip("\'")
            data[key] = int(val)

    logger.debug('%s', data)
    return data

# --------------------------------------------------------------------------------------------------

def mjd2ut(mjd):
    """
    Convert Modified Julian date to UT date and time using astropy.time
    http://docs.astropy.org/en/stable/time/
    Input:  MJD date (float)
    Output: datetime object
    """
    logger = logging.getLogger('mjd2ut')
    if not isinstance(mjd, float):
        logger.error('MJD "%s" is not a float', mjd)
        return None

    # Catch ERFA warning in older versions of astropy:
    with warnings.catch_warnings():
        warnings.filterwarnings(action='ignore',
                                message="ERFA function \"d2dtf\" yielded 1 of \"dubious year \(Note",
                                module='astropy._erfa.core')
        t = Time(mjd, format='mjd')
        t.format = 'datetime'  # convert to a datetime object
        mjdut = t.value

    logger.debug('MJD in UT: %s', mjdut)
    return mjdut

# --------------------------------------------------------------------------------------------------

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Check the GNIRS WCS by comparing with the RA and DEC keywords.  If a single ' +
        'file is specified then check only that file.  If a date or date range is specified then ' +
        'check all the files taken on those days.',
        epilog='version: ' + __version__)

    parser.add_argument('--file', default=None, help='FITS file')
    parser.add_argument('--force', action='store_true', help='Force checking every file')
    parser.add_argument('--date', default=None, help='UT date (any reasonable format, including "today")')
    parser.add_argument('--enddate', default=None, help='End Date (any reasonable format)')
    parser.add_argument('--all', action='store_true', help='Print the result for every file (not just bad ones')
    parser.add_argument('--loglevel', type=str, default='warning', choices=['debug', 'info', 'warning', 'error'],
                        help='Log level [WARNING]')
    args = parser.parse_args()

    args.webapp = True if ('cgi-bin' in os.getcwd()) else False

    if not args.webapp and ((not args.file and not args.date) or (args.file and args.date)):
        parser.error('Must specify a file or date')

    if args.date is not None:
        if args.date.lower() == 'today':
            args.date = str(datetime.datetime.utcnow().date())

    if args.enddate and not args.date:
        parser.error('Must specify start date')

    if args.file and args.loglevel == 'warning':
        args.loglevel = 'info'
        args.force = True
    
    main(args)

# --------------------------------------------------------------------------------------------------
