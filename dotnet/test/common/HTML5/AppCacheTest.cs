﻿using System;
using NUnit.Framework;

namespace OpenQA.Selenium.Html5
{
    [TestFixture]
    public class AppCacheTest : DriverTestFixture
    {
        [Test]
        [IgnoreBrowser(Browser.Android, "Untested feature")]
       // [IgnoreBrowser(Browser.Chrome, "Not implemented")]
        public void TestAppCacheStatus()
        {
            driver.Url = html5Page;
            driver.Manage().Timeouts().ImplicitlyWait(TimeSpan.FromMilliseconds(2000));
            IHasApplicationCache hasAppCacheDriver = driver as IHasApplicationCache;
            if (hasAppCacheDriver == null || !hasAppCacheDriver.HasApplicationCache)
            {
                Assert.Ignore("Driver does not support app cache");
            }

            IApplicationCache appCache = hasAppCacheDriver.ApplicationCache;
            AppCacheStatus status = appCache.Status;
            while (status == AppCacheStatus.Downloading)
            {
                status = appCache.Status;
            }

            Assert.AreEqual(AppCacheStatus.Uncached, status);
        }
    }
}
